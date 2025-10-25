import 'package:dio/dio.dart';
import 'dart:convert';

/// Сервис для работы с Firebase Auth через REST API
/// Обходит проблему с Keychain на macOS
class FirebaseAuthService {
  final Dio _dio = Dio();
  static const String _apiKey = 'AIzaSyDZDuj4wyb9S-R0jK_D3jBPPmHpxMAaggY'; // macOS API Key
  
  /// Вход через email и пароль
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_apiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data['error'];
        throw FirebaseAuthRestException(
          code: error['message'] ?? 'UNKNOWN_ERROR',
          message: _getErrorMessage(error['message'] ?? 'UNKNOWN_ERROR'),
        );
      }
      rethrow;
    }
  }
  
  /// Регистрация нового пользователя
  Future<Map<String, dynamic>> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      
      return response.data;
    } on DioException catch (e) {
      if (e.response != null) {
        final error = e.response!.data['error'];
        throw FirebaseAuthRestException(
          code: error['message'] ?? 'UNKNOWN_ERROR',
          message: _getErrorMessage(error['message'] ?? 'UNKNOWN_ERROR'),
        );
      }
      rethrow;
    }
  }
  
  /// Обновление токена
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        'https://securetoken.googleapis.com/v1/token?key=$_apiKey',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );
      
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
  
  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'EMAIL_NOT_FOUND':
        return 'Пользователь не найден';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Неверный email или пароль';
      case 'USER_DISABLED':
        return 'Учетная запись отключена';
      case 'EMAIL_EXISTS':
        return 'Email уже используется';
      case 'WEAK_PASSWORD':
        return 'Слишком слабый пароль';
      case 'INVALID_EMAIL':
        return 'Неверный email';
      default:
        return 'Ошибка авторизации: $errorCode';
    }
  }
}

class FirebaseAuthRestException implements Exception {
  final String code;
  final String message;
  
  FirebaseAuthRestException({required this.code, required this.message});
  
  @override
  String toString() => message;
}

