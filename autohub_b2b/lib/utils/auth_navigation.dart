import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/screens/auth/login_screen.dart';

/// Централизованная навигация на экран входа.
///
/// **Почему ломался сценарий с истёкшей сессией:** при [Navigator.push] на [LoginScreen]
/// пользователь остаётся в «правильном» стеке, но экран входа без leading выглядит как тупик;
/// если же где-то используется [pushAndRemoveUntil] с предикатом `(r) => false`,
/// Login оказывается единственным маршрутом — после [AuthAuthenticated] вызов
/// `if (Navigator.canPop) pop()` **не** закрывает экран. Поэтому:
/// • гостевой вход — только [pushLoginOverlay] (поверх корня, всегда есть `canPop`);
/// • после 401 / явного входа из заглушки — [pushLoginAfterSessionExpired]: сначала
/// [Navigator.popUntil] до корня приложения, затем выход из сессии и снова push Login.
class AuthNavigation {
  AuthNavigation._();

  /// Вход гостя / из AppBar: модальное окно поверх текущего shell ([MainScreen] остаётся под ним).
  /// После успешного входа достаточно одного [Navigator.pop] — пользователь возвращается
  /// в тот же раздел, где был.
  static Future<void> pushLoginOverlay(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: '/login'),
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  /// Истёкший токен / 401: убрать все открытые push-маршруты (детали, профиль и т.д.),
  /// очистить сессию и снова открыть вход **поверх** корневого маршрута приложения.
  /// Так [LoginScreen] никогда не бывает единственным маршрутом — закрытие после логина надёжно.
  ///
  /// [Navigator] и [AuthBloc] берутся из [context] **до** [Navigator.popUntil], иначе после
  /// закрытия маршрута с экрана-детали [BuildContext] кнопки будет unmounted.
  static Future<void> pushLoginAfterSessionExpired(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final authBloc = context.read<AuthBloc>();
    navigator.popUntil((route) => route.isFirst);
    authBloc.add(AuthSignOutRequested());
    await navigator.push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: const RouteSettings(name: '/login'),
        builder: (context) => const LoginScreen(),
      ),
    );
  }
}
