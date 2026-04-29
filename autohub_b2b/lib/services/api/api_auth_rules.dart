import 'package:dio/dio.dart';

/// Правила: когда HTTP-ответ означает «сессия недействительна» и нужен глобальный выход на логин.
///
/// - **401** при запросе с `Authorization` — почти всегда протухший/невалидный токен.
/// - **403** — часто роль/ACL; глобальный выход только если тело ответа явно про токен/сессию
///   (иначе пользователь увидит [UnauthorizedPlaceholder] на экране).
class ApiAuthRules {
  ApiAuthRules._();

  /// Если бэкенд при истёкшем JWT отдаёт **403** без признаков в JSON — включите `true`
  /// (глобальный выход; иначе пользователь увидит экран «Нет доступа»).
  static bool forceSessionExpiryOn403WithAuthorization = false;

  static bool requestHadAuthorization(RequestOptions o) {
    final a = o.headers['Authorization'] ?? o.headers['authorization'];
    return a != null && a.toString().trim().isNotEmpty;
  }

  /// Ответ бэкенда намекает, что проблема в JWT/сессии, а не в правах на сущность.
  static bool responseSuggestsSessionExpiry(Response? response) {
    final data = response?.data;
    if (data is Map) {
      final code = '${data['code'] ?? data['error'] ?? ''}'.toLowerCase();
      if (code.contains('token') ||
          code.contains('jwt') ||
          code.contains('session') ||
          code.contains('unauthorized') ||
          code.contains('expired')) {
        return true;
      }
      final msg = '${data['message'] ?? data['detail'] ?? ''}'.toLowerCase();
      if (msg.contains('token') &&
          (msg.contains('expired') ||
              msg.contains('invalid') ||
              msg.contains('revoked'))) {
        return true;
      }
      if (msg.contains('jwt') || msg.contains('session expired')) {
        return true;
      }
    }
    if (data is String) {
      final m = data.toLowerCase();
      if (m.contains('token') && m.contains('expir')) {
        return true;
      }
    }
    return false;
  }

  /// Сброс сессии + переход на логин только в этих случаях.
  static bool shouldInvalidateSession({
    required int statusCode,
    required RequestOptions requestOptions,
    Response? response,
  }) {
    if (!requestHadAuthorization(requestOptions)) {
      return false;
    }
    if (statusCode == 401) {
      return true;
    }
    if (statusCode == 403) {
      if (forceSessionExpiryOn403WithAuthorization) {
        return true;
      }
      return responseSuggestsSessionExpiry(response);
    }
    return false;
  }
}
