import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:autohub_b2b/services/api/api_exception.dart';
import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';

/// Извлекает текст ошибки из тела ответа API (NestJS / Express).
String? extractApiErrorMessage(dynamic data) {
  if (data == null) return null;

  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('<!') || trimmed.startsWith('<html')) return null;
    if (trimmed.length > 280) return null;
    return trimmed;
  }

  if (data is Map) {
    final message = data['message'] ?? data['error'] ?? data['detail'];
    if (message is List) {
      return message.map((e) => e.toString()).join('\n');
    }
    if (message != null) {
      return message.toString();
    }
  }

  return null;
}

/// Сообщение по HTTP-коду, если тело ответа пустое или техническое.
String messageForHttpStatus(int? statusCode) {
  switch (statusCode) {
    case 400:
      return 'Неверный запрос. Проверьте введённые данные.';
    case 401:
      return 'Сессия истекла. Войдите снова.';
    case 403:
      return 'Нет доступа к этой операции.';
    case 404:
      return 'Данные не найдены.';
    case 409:
      return 'Конфликт данных. Обновите экран и попробуйте снова.';
    case 422:
      return 'Данные не прошли проверку. Исправьте поля формы.';
    case 429:
      return 'Слишком много запросов. Подождите немного.';
    case 500:
      return 'Ошибка на сервере. Попробуйте позже.';
    case 502:
    case 503:
    case 504:
      return 'Сервер временно недоступен. Попробуйте позже.';
    default:
      if (statusCode != null && statusCode >= 500) {
        return 'Сервер временно недоступен. Попробуйте позже.';
      }
      if (statusCode != null && statusCode >= 400) {
        return 'Не удалось выполнить запрос (код $statusCode).';
      }
      return 'Не удалось выполнить запрос. Попробуйте позже.';
  }
}

bool _looksTechnical(String message) {
  final m = message.toLowerCase();
  return m.startsWith('dioexception') ||
      m.startsWith('apiexception') ||
      m.contains('status code') ||
      m.contains('status:') ||
      m.contains('(status:') ||
      m.contains('socketexception') ||
      m.contains('connection refused') ||
      m.contains('handshakeexception') ||
      m.contains('formatexception') ||
      m.startsWith('exception:') ||
      m.contains('stack trace') ||
      m.contains('failed to ') ||
      m.contains('неизвестная ошибка') ||
      m.contains('type ') && m.contains(' is not a subtype of ');
}

String _stripExceptionPrefix(String message) {
  return message.replaceFirst(
    RegExp(r'^(Exception|[A-Za-z]+Exception):\s*'),
    '',
  );
}

String _sanitizeMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return 'Не удалось выполнить операцию. Попробуйте позже.';
  }
  if (_looksTechnical(trimmed)) {
    return 'Не удалось выполнить операцию. Попробуйте позже.';
  }
  return trimmed;
}

/// Сообщение для Snackbar / подписи — без сырого JSON и stack trace.
String userFacingApiMessage(
  Object error, {
  String? prefix,
}) {
  String resolved;

  if (error is String) {
    resolved = _sanitizeMessage(error);
  } else if (error is BleEscPosException) {
    resolved = _sanitizeMessage(error.message);
  } else if (error is ApiException) {
    final fromBody = extractApiErrorMessage(error.data);
    resolved = fromBody ??
        (error.message.isNotEmpty && !_looksTechnical(error.message)
            ? error.message
            : messageForHttpStatus(error.statusCode));
    resolved = _sanitizeMessage(resolved);
  } else if (error is DioException) {
    if (isNetworkError(error)) {
      resolved = 'Нет соединения с сервером. Проверьте интернет.';
    } else {
      final code = error.response?.statusCode;
      final fromBody = extractApiErrorMessage(error.response?.data);
      resolved = fromBody ?? messageForHttpStatus(code);
      resolved = _sanitizeMessage(resolved);
    }
  } else if (error is Exception) {
    resolved = _sanitizeMessage(_stripExceptionPrefix(error.toString()));
  } else {
    resolved = _sanitizeMessage(_stripExceptionPrefix(error.toString()));
  }

  if (prefix != null && prefix.trim().isNotEmpty) {
    return '$prefix: $resolved';
  }
  return resolved;
}

void showApiErrorSnackBar(
  BuildContext context,
  Object error, {
  String? prefix,
  Color backgroundColor = Colors.red,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(userFacingApiMessage(error, prefix: prefix)),
      backgroundColor: backgroundColor,
    ),
  );
}
