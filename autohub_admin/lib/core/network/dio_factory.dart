import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../network/auth_navigator.dart';
import '../network/http_log_interceptor.dart';
import '../storage/secure_token_storage.dart';

class DioFactory {
  DioFactory(this._tokens);

  final SecureTokenStorage _tokens;

  Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.dioBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 45),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokens.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;

          final isAuthRoute = path.contains('/api/auth/login') ||
              path.contains('/api/auth/refresh');

          if (status == 401 && !isAuthRoute) {
            await _tokens.clearAll();
            AuthNavigator.onUnauthorized?.call();
          } else if (status == 403 && !isAuthRoute) {
            final msg = _messageFromResponse(error.response?.data) ??
                'You do not have permission to perform this action.';
            AuthNavigator.onForbidden?.call(msg);
          }

          handler.next(error);
        },
      ),
    );

    dio.interceptors.add(HttpLogInterceptor());

    return dio;
  }

  String? _messageFromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final m = data['message'];
      if (m is String) return m;
      if (m is List && m.isNotEmpty && m.first is String) {
        return m.first as String;
      }
    }
    return null;
  }
}
