import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API base URL for Dio (должен совпадать с тем, что отдаёт Nest: префикс `/api` у контроллеров).
///
/// Приоритет:
/// 1. `--dart-define=API_BASE_URL=...` (CI / релиз)
/// 2. переменная окружения процесса `API_BASE_URL` (локально: `API_BASE_URL=... flutter run`)
/// 3. файл `assets/env/app.env` ([flutter_dotenv](https://pub.dev/packages/flutter_dotenv))
class AppConfig {
  AppConfig._();

  static late final String apiBaseUrl;

  /// Вызывать после `WidgetsFlutterBinding.ensureInitialized()` и после `dotenv.load(...)`.
  static void resolveAfterEnvLoaded() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    if (fromDefine.trim().isNotEmpty) {
      apiBaseUrl = _normalizeBase(fromDefine);
      return;
    }

    final fromPlatform = Platform.environment['API_BASE_URL'];
    if (fromPlatform != null && fromPlatform.trim().isNotEmpty) {
      apiBaseUrl = _normalizeBase(fromPlatform);
      return;
    }

    final fromFile = dotenv.env['API_BASE_URL'];
    if (fromFile != null && fromFile.trim().isNotEmpty) {
      apiBaseUrl = _normalizeBase(fromFile);
      return;
    }

    throw StateError(
      'API_BASE_URL is not set. Add assets/env/app.env, export API_BASE_URL, '
      'or pass --dart-define=API_BASE_URL=https://host/api',
    );
  }

  static String _normalizeBase(String raw) {
    var s = raw.trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static const String superadminRole = 'superadmin';

  static const int defaultPageSize = 20;
}
