import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'package:autohub_b2b/core/app_navigator_key.dart';
import 'package:autohub_b2b/utils/auth_navigation.dart';

/// Единая реакция на 401 / «протухшую» сессию из API: сброс навигатора + экран входа.
/// Дедупликация: параллельные запросы не открывают несколько модалок.
class SessionExpiredCoordinator {
  SessionExpiredCoordinator._();
  static final SessionExpiredCoordinator instance = SessionExpiredCoordinator._();

  bool _frameScheduled = false;
  bool _navigationInFlight = false;

  /// Вызывать из [Dio] interceptor после очистки токена (или до — см. [AuthNavigation]).
  void scheduleNavigateToLogin() {
    if (_frameScheduled) {
      return;
    }
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _frameScheduled = false;
      if (_navigationInFlight) {
        return;
      }
      _navigationInFlight = true;
      try {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) {
          return;
        }
        try {
          await AuthNavigation.pushLoginAfterSessionExpired(ctx);
        } catch (e, st) {
          assert(() {
            debugPrint('SessionExpiredCoordinator: $e\n$st');
            return true;
          }());
        }
      } finally {
        _navigationInFlight = false;
      }
    });
  }
}
