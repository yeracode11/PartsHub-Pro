import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/core/phone/phone_utils.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SecureStorageService _storage = SecureStorageService();
  String get _authBaseUrl => Environment.apiBaseUrl.replaceAll('/api', '');

  Dio _authDio() {
    return Dio(
      BaseOptions(
        baseUrl: _authBaseUrl,
        connectTimeout: Environment.connectTimeout,
        receiveTimeout: Environment.receiveTimeout,
        sendTimeout: Environment.receiveTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Ответ 401/403 часто приходит HTML/текстом с прокси — не обращаемся к data как к Map вслепую.
  String _messageFromAuthResponse(Response? response) {
    final data = response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    final code = response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Неверный телефон или пароль';
    }
    return 'Неверный телефон или пароль';
  }

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
      // Добавляем защиту от зависаний: ограничиваем время ожидания
      final userData = await _storage
          .getUserData()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      final token = await _storage
          .getAuthToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);

      if (userData != null && token != null) {
        try {
          final userModel = UserModel(
            uid: userData['uid'] ?? '',
            name: userData['name'] ?? 'User',
            email: userData['email'] ?? '',
            role: _parseRole(userData['role']),
            businessType: _parseBusinessType(userData['businessType']),
            createdAt: DateTime.parse(userData['createdAt'] ?? DateTime.now().toIso8601String()),
          );

          try {
            await ApiClient().dio.get('/api/auth/me').timeout(
                  const Duration(seconds: 10),
                );
          } on DioException catch (e) {
            final sc = e.response?.statusCode;
            if (sc == 401 || sc == 403) {
              await _storage.clearAll();
              emit(AuthUnauthenticated());
              return;
            }
          } on TimeoutException {
            //
          }

          emit(AuthAuthenticated(userModel));
          unawaited(ServiceLocator().syncService.syncAll());
        } catch (e) {
          await _storage.clearAll();
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(userFacingApiMessage(e)));
    }
  }

  Future<void> _onSignInRequested(
      AuthSignInRequested event, Emitter<AuthState> emit) async {
    try {
      emit(AuthLoading());
      await _storage.clearAll();

      final dio = _authDio();
      final phone = PhoneUtils.normalizeToE164(event.phone);
      if (phone == null) {
        emit(const AuthError('Введите корректный номер телефона'));
        return;
      }

      final jwtResponse = await dio.post('/api/auth/login', data: {
        'phone': phone,
        'password': event.password,
      });

      final jwtData = jwtResponse.data;
      final organizationPhone = jwtData['user']?['organization']?['phone'];

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
        if (organizationPhone != null) 'phone': organizationPhone,
      });
      
      await _storage.saveAuthTokens(
        authToken: jwtData['accessToken'],  // JWT токен!
        refreshToken: jwtData['refreshToken'],
      );
      
      emit(AuthAuthenticated(userModel));
      unawaited(ServiceLocator().syncService.syncAll());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.message?.contains('Connection refused') == true) {
        emit(AuthError(
          'Не удалось подключиться к серверу. Проверьте сеть и что backend доступен.',
        ));
        return;
      }
      if (e.response != null) {
        emit(AuthError(_messageFromAuthResponse(e.response)));
      } else {
        emit(AuthError('Ошибка подключения к серверу'));
      }
    } catch (e) {
      emit(AuthError(userFacingApiMessage(e)));
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
      emit(AuthLoading());
      await _storage.clearAll();

      final dio = _authDio();
      final phone = PhoneUtils.normalizeToE164(event.phone);
      if (phone == null) {
        emit(const AuthError('Введите корректный номер телефона'));
        return;
      }

      final registerResponse = await dio.post('/api/auth/register', data: {
        'phone': phone,
        'password': event.password,
        'name': event.name.trim(),
        'organizationName': event.organizationName.trim(),
        'role': event.role,
      });

      final registerData = registerResponse.data;
      final userPhone = registerData['user']?['phone'];
      final organizationPhone = registerData['user']?['organization']?['phone'];

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
        if (userPhone != null)
          'phone': userPhone
        else if (organizationPhone != null)
          'phone': organizationPhone,
      });
      
      await _storage.saveAuthTokens(
        authToken: registerData['accessToken'],
        refreshToken: registerData['refreshToken'],
      );
      
      emit(AuthAuthenticated(userModel));
      unawaited(ServiceLocator().syncService.syncAll());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.message?.contains('Connection refused') == true) {
        emit(AuthError(
          'Не удалось подключиться к серверу. Проверьте сеть и что backend доступен.',
        ));
        return;
      }
      if (e.response != null) {
        emit(AuthError(userFacingApiMessage(e)));
      } else {
        emit(AuthError('Ошибка подключения к серверу'));
      }
    } catch (e) {
      emit(AuthError(userFacingApiMessage(e)));
    }
  }

  Future<void> _onSignOutRequested(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    try {
      await _storage.clearAll();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(userFacingApiMessage(e)));
    }
  }

  Future<void> _onProfileUpdated(
      AuthProfileUpdated event, Emitter<AuthState> emit) async {
    try {
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
    } catch (e) {
      emit(AuthError(userFacingApiMessage(e)));
    }
  }
}

