import 'package:dio/dio.dart';

import '../../../core/network/api_helpers.dart';
import 'models/admin_user.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    return guardApi(() async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = res.data ?? {};
      final token = data['accessToken'] as String? ?? '';
      final refresh = data['refreshToken'] as String?;
      final userMap = data['user'];
      if (userMap is! Map<String, dynamic>) {
        throw StateError('Invalid login response: missing user');
      }
      final user = AdminUser.fromJson(userMap);
      return AuthSession(accessToken: token, refreshToken: refresh, user: user);
    });
  }

  /// Validates the stored JWT and returns the current principal (`GET /auth/me`).
  Future<AdminUser> me() {
    return guardApi(() async {
      final res = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = res.data ?? {};
      return AdminUser.fromJson(data);
    });
  }
}
