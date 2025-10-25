/// Кастомные исключения для API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({String? message})
      : super(
          message: message ?? 'Нет подключения к интернету',
          statusCode: null,
        );
}

class TimeoutException extends ApiException {
  TimeoutException()
      : super(
          message: 'Превышено время ожидания',
          statusCode: 408,
        );
}

class UnauthorizedException extends ApiException {
  UnauthorizedException()
      : super(
          message: 'Необходима авторизация',
          statusCode: 401,
        );
}

class ForbiddenException extends ApiException {
  ForbiddenException()
      : super(
          message: 'Доступ запрещен',
          statusCode: 403,
        );
}

class NotFoundException extends ApiException {
  NotFoundException({String? message})
      : super(
          message: message ?? 'Ресурс не найден',
          statusCode: 404,
        );
}

class ServerException extends ApiException {
  ServerException({String? message})
      : super(
          message: message ?? 'Ошибка сервера',
          statusCode: 500,
        );
}

class ValidationException extends ApiException {
  ValidationException({required String message, dynamic data})
      : super(
          message: message,
          statusCode: 422,
          data: data,
        );
}

