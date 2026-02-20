import 'package:dio/dio.dart';
import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/services/api/api_exception.dart';

/// Базовый класс для всех API сервисов
class BaseApiService {
  late final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  BaseApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Environment.apiBaseUrl,
        connectTimeout: Environment.connectTimeout,
        receiveTimeout: Environment.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Interceptor для добавления токена авторизации
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAuthToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (error, handler) async {
          return handler.next(error);
        },
      ),
    );

    // Логирование (только в dev режиме)
    if (Environment.enableApiLogs) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  /// GET запрос
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// POST запрос
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// PUT запрос
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// DELETE запрос
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// PATCH запрос
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'Неизвестная ошибка: $e');
    }
  }

  /// Обработка ошибок Dio
  ApiException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException();

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response?.data);

        switch (statusCode) {
          case 400:
            return ValidationException(
              message: message ?? 'Неверный запрос',
              data: error.response?.data,
            );
          case 401:
            return UnauthorizedException();
          case 403:
            return ForbiddenException();
          case 404:
            return NotFoundException(message: message);
          case 422:
            return ValidationException(
              message: message ?? 'Ошибка валидации',
              data: error.response?.data,
            );
          case 500:
          case 502:
          case 503:
            return ServerException(message: message);
          default:
            return ApiException(
              message: message ?? 'Ошибка сервера',
              statusCode: statusCode,
              data: error.response?.data,
            );
        }

      case DioExceptionType.connectionError:
        // Проверяем, содержит ли сообщение об ошибке "Connection refused"
        if (error.message?.contains('Connection refused') == true) {
          return ApiException(
            message: 'Сервер недоступен. Проверьте, что backend запущен на ${error.requestOptions.baseUrl}',
          );
        }
        return NetworkException(
          message: 'Не удалось подключиться к серверу. Убедитесь, что backend запущен.',
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Запрос отменен');

      default:
        // Проверяем сообщение об ошибке для более точной диагностики
        if (error.message?.contains('Connection refused') == true) {
          return ApiException(
            message: 'Сервер недоступен. Проверьте, что backend запущен.',
          );
        }
        return ApiException(
          message: error.message ?? 'Неизвестная ошибка',
        );
    }
  }

  /// Извлечение сообщения об ошибке из ответа
  String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    
    if (data is Map<String, dynamic>) {
      // Пробуем разные варианты полей с сообщением
      return data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String?;
    }
    
    if (data is String) {
      return data;
    }
    
    return null;
  }
}

