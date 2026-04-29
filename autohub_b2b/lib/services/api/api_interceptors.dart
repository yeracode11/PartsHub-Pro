import 'package:dio/dio.dart';

import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/api/api_auth_rules.dart';
import 'package:autohub_b2b/services/api/session_expired_coordinator.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';

/// Общие перехватчики для всех [Dio], работающих с backend (токен, сеть, истёкшая сессия).
void attachCoreApiInterceptors(
  Dio dio, {
  bool? enableLogging,
}) {
  final logRequests = enableLogging ?? Environment.enableApiLogs;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorageService().getAuthToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        ConnectivityService().reportOnline();
        return handler.next(response);
      },
      onError: (error, handler) async {
        final err = error;
        if (err.type == DioExceptionType.badResponse) {
          final sc = err.response?.statusCode;
          if (sc != null &&
              ApiAuthRules.shouldInvalidateSession(
                statusCode: sc,
                requestOptions: err.requestOptions,
                response: err.response,
              )) {
            try {
              await SecureStorageService().clearAll();
            } catch (_) {}
            SessionExpiredCoordinator.instance.scheduleNavigateToLogin();
          }
        }

        if (_isNetworkError(err)) {
          ConnectivityService().reportOffline();
        }

        return handler.next(err);
      },
    ),
  );

  if (logRequests) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }
}

bool _isNetworkError(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return true;
    default:
      return false;
  }
}
