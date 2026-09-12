import 'package:dio/dio.dart';
import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/api/api_interceptors.dart';
import 'package:autohub_b2b/services/api/api_exception.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Базовый класс для всех API сервисов
class BaseApiService {
  late final Dio _dio;

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

    attachCoreApiInterceptors(_dio);
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
      throw ApiException(message: 'Не удалось выполнить операцию. Попробуйте позже.');
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
      throw ApiException(message: 'Не удалось выполнить операцию. Попробуйте позже.');
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
      throw ApiException(message: 'Не удалось выполнить операцию. Попробуйте позже.');
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
      throw ApiException(message: 'Не удалось выполнить операцию. Попробуйте позже.');
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
      throw ApiException(message: 'Не удалось выполнить операцию. Попробуйте позже.');
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
  String? _extractErrorMessage(dynamic data) => extractApiErrorMessage(data);
}

