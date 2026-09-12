import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment.dart';

class ApiClient {
  static String get baseUrl => Environment.apiBaseUrl;

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Environment.connectTimeout,
        receiveTimeout: Environment.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Добавляем интерцепторы
    _dio.interceptors.addAll([
      if (kDebugMode)
        LogInterceptor(
          request: true,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Добавляем токен авторизации если есть
          final token = await getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Обработка ошибок
          if (error.response?.statusCode == 401) {
            print('⚠️ 401 Error - clearing auth token');
            // Токен истек или невалиден - очищаем токен
            await clearAuthToken();
            print('✅ Auth token cleared - user needs to re-login');
          }
          return handler.next(error);
        },
      ),
    ]);
  }

  // Преобразует относительный URL изображения в полный URL
  static String getImageUrl(String imageUrl, {int? width, int? height}) {
    if (imageUrl.isEmpty) {
      return '';
    }

    final assetBase = Uri.parse(baseUrl.replaceAll(RegExp(r'/api/?$'), ''));
    final resolved = imageUrl.startsWith('http')
        ? imageUrl
        : '${assetBase.origin}${imageUrl.startsWith('/') ? imageUrl : '/$imageUrl'}';

    final uri = Uri.tryParse(resolved);
    if (uri == null) return resolved;

    // В БД часто сохранены URL с :3000, а API слушает :3001
    if (uri.port == 3000 && assetBase.host == uri.host) {
      final port = assetBase.hasPort ? assetBase.port : 3001;
      return uri.replace(port: port).toString();
    }

    return resolved;
  }

  Dio get dio => _dio;

  Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<SharedPreferences> getPrefs() => SharedPreferences.getInstance();

  // Generic GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return Exception('Превышено время ожидания подключения');
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? 'Неизвестная ошибка сервера';
          return Exception('Ошибка сервера ($statusCode): $message');
        case DioExceptionType.cancel:
          return Exception('Запрос отменен');
        default:
          return Exception('Ошибка сети: ${error.message}');
      }
    }
    return Exception('Неизвестная ошибка: $error');
  }
}
