import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

/// Логирует запросы/ответы/ошибки Dio без паролей и без значения Bearer-токена.
class HttpLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasAuth = options.headers['Authorization'] != null;
    AppLogger.info(
      'HTTP → ${options.method} ${options.uri} '
      '(auth: ${hasAuth ? 'yes' : 'no'})',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    AppLogger.info(
      'HTTP ← ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final uri = err.requestOptions.uri;
    final status = err.response?.statusCode;
    final type = err.type.name;

    final buf = StringBuffer()
      ..write('HTTP ✗ $type')
      ..write(' uri=$uri');
    if (status != null) {
      buf.write(' status=$status');
    }
    if (err.message != null && err.message!.isNotEmpty) {
      buf.write(' msg=${err.message}');
    }
    AppLogger.error(buf.toString());

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        AppLogger.warn(
          'Таймаут: проверьте сеть, что сервер доступен по этому URL и порт не блокируется файрволом.',
        );
        break;
      case DioExceptionType.connectionError:
        AppLogger.warn(
          'Connection error: не удалось установить TCP-соединение. '
          'Проверьте API_BASE_URL (хост/порт), что бэкенд слушает PORT, HTTP vs HTTPS, доступность с этой машины (ping/curl).',
        );
        break;
      case DioExceptionType.badCertificate:
        AppLogger.warn(
          'Сертификат TLS отклонён. Для самоподписанного HTTPS нужна своя настройка в Dio (или временно HTTP только в дев).',
        );
        break;
      case DioExceptionType.badResponse:
        final data = err.response?.data;
        if (data != null) {
          final snippet = data.toString();
          final cut = snippet.length > 500 ? '${snippet.substring(0, 500)}…' : snippet;
          AppLogger.info('HTTP ответ с ошибкой body: $cut');
        }
        break;
      default:
        break;
    }

    if (kDebugMode) {
      debugPrint('[AutoHubAdmin] Dio stack:\n${err.stackTrace}');
    }

    handler.next(err);
  }
}
