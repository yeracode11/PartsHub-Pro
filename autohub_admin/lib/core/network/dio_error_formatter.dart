import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Человекочитаемое сообщение для Snackbar / состояния без утечки лишних данных.
String formatHttpError(Object error) {
  if (error is AppException) {
    return error.message;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Время ожидания ответа истекло. Проверьте подключение к интернету.';
      case DioExceptionType.connectionError:
        return 'Сервер временно недоступен. Проверьте интернет или повторите позже.';
      case DioExceptionType.badCertificate:
        return 'Ошибка безопасного соединения (SSL).';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        final data = error.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
        return 'Ошибка сервера${code != null ? ' ($code)' : ''}.';
      case DioExceptionType.cancel:
        return 'Запрос отменён.';
      case DioExceptionType.unknown:
        return error.message ?? 'Неизвестная сетевая ошибка.';
    }
  }
  return error.toString();
}
