import 'package:dio/dio.dart';

import 'package:autohub_b2b/widgets/offline_placeholder.dart';

/// Сообщение для Snackbar / подписи к плейсхолдеру — **без** сырых JSON и stack trace.
String userFacingApiMessage(Object error) {
  if (error is String && error.trim().isNotEmpty) {
    return error.trim();
  }
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 403) {
      return 'Нет доступа к этой операции. Обратитесь к администратору.';
    }
    if (code == 401) {
      return 'Требуется вход в систему.';
    }
    if (code == 404) {
      return 'Данные не найдены.';
    }
    if (code != null && code >= 500) {
      return 'Сервер временно недоступен. Попробуйте позже.';
    }
    if (isNetworkError(error)) {
      return 'Нет соединения с сервером. Проверьте интернет.';
    }
  }
  return 'Не удалось выполнить запрос. Попробуйте позже.';
}
