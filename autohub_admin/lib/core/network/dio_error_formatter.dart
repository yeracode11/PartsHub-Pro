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
        return 'Таймаут соединения с сервером. Проверьте адрес API и сеть.';
      case DioExceptionType.connectionError:
        return 'Нет соединения с сервером (${error.message ?? 'connection error'}). '
            'Проверьте API_BASE_URL и что бэкенд запущен.';
      case DioExceptionType.badCertificate:
        return 'Ошибка сертификата HTTPS.';
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
