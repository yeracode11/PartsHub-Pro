import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/services/auth/firebase_auth_service.dart';
import 'package:dio/dio.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final SecureStorageService _storage = SecureStorageService();

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      // Проверяем сохраненные данные пользователя
      final userData = await _storage.getUserData();
      final token = await _storage.getAuthToken();

      if (userData != null && token != null) {
        print('✅ AuthBloc: Found saved user data');
        print('   Token starts with: ${token.substring(0, 30)}...');
        
        // Проверяем что токен не Firebase (RS256)
        if (token.startsWith('eyJhbGciOiJSUzI1NiIs')) {
          print('⚠️ AuthBloc: Old Firebase token detected, clearing...');
          await _storage.clearAll();
          emit(AuthUnauthenticated());
          return;
        }
        
        final userModel = UserModel(
          uid: userData['uid'],
          name: userData['name'] ?? 'User',
          email: userData['email'] ?? '',
          role: UserRole.values.firstWhere(
            (e) => e.toString() == userData['role'],
            orElse: () => UserRole.owner,
          ),
          businessType: BusinessType.values.firstWhere(
            (e) => e.toString() == userData['businessType'],
            orElse: () => BusinessType.service,
          ),
          createdAt: DateTime.parse(userData['createdAt']),
        );
        emit(AuthAuthenticated(userModel));
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
      emit(AuthLoading());
      
      // Шаг 1: Авторизация через Firebase (получаем ID Token)
      final firebaseResponse = await _authService.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      print('✅ AuthBloc: Firebase auth successful');
      print('   Firebase ID Token: ${firebaseResponse['idToken'].substring(0, 20)}...');

      // Шаг 2: Обмениваем Firebase ID Token на JWT от нашего бэкенда
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
      final jwtResponse = await dio.post('/api/auth/login', data: {
        'email': event.email,
        'firebaseIdToken': firebaseResponse['idToken'],
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
      print('❌ AuthBloc: DioException - ${e.response?.data}');
      emit(AuthError(e.response?.data['message'] ?? 'Ошибка авторизации'));
    } on FirebaseAuthRestException catch (e) {
      print('❌ AuthBloc: FirebaseAuthRestException - ${e.message}');
      emit(AuthError(e.message));
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
      case 'dismantler':
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
      emit(AuthLoading());
      
      // Используем REST API вместо Firebase SDK (обход Keychain)
      final response = await _authService.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      final userModel = UserModel(
        uid: response['localId'],
        name: event.name,
        email: event.email,
        role: event.role,
        businessType: event.businessType,
        createdAt: DateTime.now(),
      );

      // Сохраняем данные пользователя и токены локально
      await _storage.saveUserData({
        'uid': userModel.uid,
        'name': userModel.name,
        'email': userModel.email,
        'role': userModel.role.toString(),
        'businessType': userModel.businessType.toString(),
        'createdAt': userModel.createdAt.toIso8601String(),
      });
      
      await _storage.saveAuthTokens(
        authToken: response['idToken'],
        refreshToken: response['refreshToken'],
      );
      
      emit(AuthAuthenticated(userModel));
    } on FirebaseAuthRestException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(AuthError('Произошла ошибка: $e'));
    }
  }

  Future<void> _onSignOutRequested(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    try {
      await _storage.clearAll();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}

