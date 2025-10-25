import 'package:dio/dio.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Ошибка входа: $e');
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post(
        '/api/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Ошибка обновления токена: $e');
    }
  }

  Future<void> logout() async {
    // Очистка токенов из локального хранилища
    // В реальном приложении здесь будет вызов API для logout
  }
}
