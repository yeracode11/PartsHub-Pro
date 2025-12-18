import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:dio/dio.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SecureStorageService _storage = SecureStorageService();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthProfileUpdated>(_onProfileUpdated);
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      // Проверяем сохраненные данные пользователя
      final userData = await _storage.getUserData();
      final token = await _storage.getAuthToken();

      if (userData != null && token != null) {
        print('✅ AuthBloc: Found saved user data, restoring session');
        // Восстанавливаем пользователя из сохраненных данных
        try {
          final userModel = UserModel(
            uid: userData['uid'] ?? '',
            name: userData['name'] ?? 'User',
            email: userData['email'] ?? '',
            role: _parseRole(userData['role']),
            businessType: _parseBusinessType(userData['businessType']),
            createdAt: DateTime.parse(userData['createdAt'] ?? DateTime.now().toIso8601String()),
          );
          emit(AuthAuthenticated(userModel));
          print('✅ AuthBloc: User session restored');
        } catch (e) {
          print('❌ AuthBloc: Error restoring user session: $e');
          await _storage.clearAll();
          emit(AuthUnauthenticated());
        }
      } else {
        print('ℹ️ AuthBloc: No saved user data found');
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      print('❌ AuthBloc: Error checking auth - $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInRequested(
      AuthSignInRequested event, Emitter<AuthState> emit) async {
    try {
      print('🔐 AuthBloc: Starting sign in...');
      
      // Очищаем старые токены перед входом
      await _storage.clearAll();
      print('🧹 Cleared old tokens');
      
      emit(AuthLoading());
      
      // Шаг 1: Прямая авторизация через наш бэкенд
      final dio = Dio(BaseOptions(baseUrl: 'http://78.140.246.83:3000'));
      final jwtResponse = await dio.post('/api/auth/login', data: {
        'email': event.email,
        'password': event.password,
      });

      final jwtData = jwtResponse.data;
      print('✅ AuthBloc: JWT auth successful!');
      print('   User: ${jwtData['user']['name']}');
      print('   Role: ${jwtData['user']['role']}');
      print('   Organization: ${jwtData['user']['organization']['name']}');

      // Шаг 3: Создаем UserModel из данных бэкенда
      final userModel = UserModel(
        uid: jwtData['user']['id'],
        name: jwtData['user']['name'] ?? 'User',
        email: jwtData['user']['email'],
        role: _parseRole(jwtData['user']['role']),
        businessType: _parseBusinessType(jwtData['user']['organization']['businessType']),
        createdAt: DateTime.now(),
      );
      
      // Шаг 4: Сохраняем JWT токены и полные данные пользователя
      await _storage.saveUserData({
        'uid': userModel.uid,
        'name': userModel.name,
        'email': userModel.email,
        'role': userModel.role.toString(),
        'businessType': userModel.businessType.toString(),
        'createdAt': userModel.createdAt.toIso8601String(),
        'organizationId': jwtData['user']['organizationId'],
        'organization': jwtData['user']['organization'],
      });
      
      await _storage.saveAuthTokens(
        authToken: jwtData['accessToken'],  // JWT токен!
        refreshToken: jwtData['refreshToken'],
      );
      
      print('✅ AuthBloc: JWT tokens and user data saved');
      emit(AuthAuthenticated(userModel));
      print('✅ AuthBloc: AuthAuthenticated state emitted');
    } on DioException catch (e) {
      print('❌ AuthBloc: DioException');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Response: ${e.response?.data}');
      print('   Status Code: ${e.response?.statusCode}');
      
      // Обработка ошибок подключения
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout ||
          e.message?.contains('Connection refused') == true) {
        emit(AuthError('Не удалось подключиться к серверу. Проверьте, что backend запущен.'));
        return;
      }
      
      // Обработка HTTP ошибок
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 
                            e.response?.data['error'] ?? 
                            'Неверный email или пароль';
        emit(AuthError(errorMessage));
      } else {
        emit(AuthError('Ошибка подключения к серверу'));
      }
    } catch (e) {
      print('❌ AuthBloc: Generic error - $e');
      emit(AuthError('Произошла ошибка: $e'));
    }
  }

  UserRole _parseRole(String? role) {
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
        return UserRole.manager;
      case 'storekeeper':
        return UserRole.storekeeper;
      case 'worker':
        return UserRole.worker;
      default:
        return UserRole.owner;
    }
  }

  BusinessType _parseBusinessType(String? type) {
    switch (type) {
      case 'service':
        return BusinessType.service;
      case 'parts': // соответствует backend BusinessType.PARTS
      case 'dismantler': // совместимость со старым значением
        return BusinessType.dismantler;
      case 'carwash':
        return BusinessType.carwash;
      default:
        return BusinessType.service;
    }
  }

  Future<void> _onSignUpRequested(
      AuthSignUpRequested event, Emitter<AuthState> emit) async {
    try {
      print('📝 AuthBloc: Starting registration...');
      
      // Очищаем старые токены перед регистрацией
      await _storage.clearAll();
      print('🧹 Cleared old tokens');
      
      emit(AuthLoading());
      
      // Регистрация через наш бэкенд
      final dio = Dio(BaseOptions(baseUrl: 'http://78.140.246.83:3000'));
      final registerResponse = await dio.post('/api/auth/register', data: {
        'email': event.email,
        'password': event.password,
        'name': event.name,
        if (event.organizationName != null) 'organizationName': event.organizationName,
        if (event.businessType != null) 'businessType': event.businessType,
      });

      final registerData = registerResponse.data;
      print('✅ AuthBloc: Registration successful!');
      print('   User: ${registerData['user']['name']}');
      print('   Role: ${registerData['user']['role']}');
      print('   Organization: ${registerData['user']['organization']['name']}');

      // Создаем UserModel из данных бэкенда
      final userModel = UserModel(
        uid: registerData['user']['id'],
        name: registerData['user']['name'] ?? 'User',
        email: registerData['user']['email'],
        role: _parseRole(registerData['user']['role']),
        businessType: _parseBusinessType(registerData['user']['organization']['businessType']),
        createdAt: DateTime.now(),
      );
      
      // Сохраняем JWT токены и полные данные пользователя
      await _storage.saveUserData({
        'uid': userModel.uid,
        'name': userModel.name,
        'email': userModel.email,
        'role': userModel.role.toString(),
        'businessType': userModel.businessType.toString(),
        'createdAt': userModel.createdAt.toIso8601String(),
        'organizationId': registerData['user']['organizationId'],
        'organization': registerData['user']['organization'],
      });
      
      await _storage.saveAuthTokens(
        authToken: registerData['accessToken'],
        refreshToken: registerData['refreshToken'],
      );
      
      print('✅ AuthBloc: JWT tokens and user data saved');
      emit(AuthAuthenticated(userModel));
      print('✅ AuthBloc: AuthAuthenticated state emitted');
    } on DioException catch (e) {
      print('❌ AuthBloc: DioException');
      print('   Type: ${e.type}');
      print('   Message: ${e.message}');
      print('   Response: ${e.response?.data}');
      print('   Status Code: ${e.response?.statusCode}');
      
      // Обработка ошибок подключения
      if (e.type == DioExceptionType.connectionError || 
          e.type == DioExceptionType.connectionTimeout ||
          e.message?.contains('Connection refused') == true) {
        emit(AuthError('Не удалось подключиться к серверу. Проверьте, что backend запущен.'));
        return;
      }
      
      // Обработка HTTP ошибок
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 
                            e.response?.data['error'] ?? 
                            'Ошибка регистрации';
        emit(AuthError(errorMessage));
      } else {
        emit(AuthError('Ошибка подключения к серверу'));
      }
    } catch (e) {
      print('❌ AuthBloc: Generic error - $e');
      emit(AuthError('Произошла ошибка: $e'));
    }
  }

  Future<void> _onSignOutRequested(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    try {
      print('🚪 AuthBloc: Signing out...');
      await _storage.clearAll();
      print('✅ AuthBloc: Storage cleared');
      emit(AuthUnauthenticated());
      print('✅ AuthBloc: AuthUnauthenticated state emitted');
    } catch (e) {
      print('❌ AuthBloc: Error signing out: $e');
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onProfileUpdated(
      AuthProfileUpdated event, Emitter<AuthState> emit) async {
    try {
      print('📝 AuthBloc: Updating profile...');
      
      // Обновляем сохраненные данные пользователя
      await _storage.saveUserData({
        'uid': event.user.uid,
        'name': event.user.name,
        'email': event.user.email,
        'role': event.user.role.toString(),
        'businessType': event.user.businessType.toString(),
        'createdAt': event.user.createdAt.toIso8601String(),
      });
      
      // Обновляем состояние
      emit(AuthAuthenticated(event.user));
      print('✅ AuthBloc: Profile updated');
    } catch (e) {
      print('❌ AuthBloc: Error updating profile: $e');
      emit(AuthError(e.toString()));
    }
  }
}

