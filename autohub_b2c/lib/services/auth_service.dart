import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  static const _refreshKey = 'refresh_token';
  static const _profileKey = 'b2c_customer_profile';

  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _apiClient.get('/auth/me');
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException {
      return null;
    }
  }

  Future<bool> hasToken() async {
    final token = await _apiClient.getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _apiClient.clearAuthToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshKey);
    await prefs.remove(_profileKey);
  }

  Future<void> persistSession(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null) await _apiClient.setAuthToken(access);
    final prefs = await SharedPreferences.getInstance();
    if (refresh != null) await prefs.setString(_refreshKey, refresh);
    final user = data['user'];
    if (user is Map) {
      await prefs.setString(_profileKey, json.encode(user));
    }
  }
}
