import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Используем production API для всех режимов
  static const String baseUrl = 'http://78.140.246.83:3000/api';

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Добавляем интерцепторы
    _dio.interceptors.addAll([
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
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
      // Если нет изображения, возвращаем placeholder из интернета
      return _getPlaceholderImageUrl(width ?? 400, height ?? 400);
    }
    
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }
    // Извлекаем базовый URL без /api
    final baseUrlWithoutApi = baseUrl.replaceAll('/api', '');
    return '$baseUrlWithoutApi$imageUrl';
  }

  // Получает URL placeholder изображения из интернета
  static String _getPlaceholderImageUrl(int width, int height) {
    // Используем Picsum Photos - бесплатный сервис placeholder изображений
    // Можно также использовать: placeholder.com, dummyimage.com
    return 'https://picsum.photos/$width/$height?random=${DateTime.now().millisecondsSinceEpoch}';
    
    // Альтернативные источники placeholder изображений:
    // 'https://via.placeholder.com/${width}x${height}?text=No+Image'
    // 'https://dummyimage.com/${width}x${height}/cccccc/999999&text=No+Image'
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
