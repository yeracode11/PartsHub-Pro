import 'package:flutter/foundation.dart';

/// Логи в консоль Xcode / `flutter run` (префикс `[AutoHubAdmin]`).
class AppLogger {
  AppLogger._();

  static const String _tag = '[AutoHubAdmin]';

  static void info(String message) {
    debugPrint('$_tag $message');
  }

  static void warn(String message) {
    debugPrint('$_tag WARN: $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('$_tag ERROR: $message');
    if (error != null) {
      debugPrint('$_tag   cause: $error');
    }
    if (stackTrace != null) {
      debugPrint('$_tag stack:\n$stackTrace');
    }
  }
}
