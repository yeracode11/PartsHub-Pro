import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/injection/app_dependencies.dart';
import '../core/logging/app_logger.dart';
import '../core/network/auth_navigator.dart';
import '../core/theme/admin_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/access_denied_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/subscriptions/presentation/bloc/subscriptions_bloc.dart';
import 'features/transactions/presentation/bloc/transactions_bloc.dart';
import 'features/users/presentation/bloc/users_bloc.dart';
import 'shell/admin_shell.dart';

class AutoHubAdminApp extends StatefulWidget {
  const AutoHubAdminApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<AutoHubAdminApp> createState() => _AutoHubAdminAppState();
}

class _AutoHubAdminAppState extends State<AutoHubAdminApp> {
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(
      authApi: widget.deps.authApi,
      tokenStorage: widget.deps.tokenStorage,
    )..add(const AuthStarted());

    AuthNavigator.onUnauthorized = () {
      AppLogger.warn('401 Unauthorized → сессия сброшена, экран входа');
      _authBloc.add(const AuthSessionExpired());
    };
    AuthNavigator.onForbidden = (message) {
      AppLogger.warn('403 Forbidden: ${message ?? '(no message)'}');
      final nav = AuthNavigator.navigatorKey.currentState;
      if (nav == null) return;
      nav.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ForbiddenPage(message: message ?? ''),
        ),
      );
    };
  }

  @override
  void dispose() {
    AuthNavigator.onUnauthorized = null;
    AuthNavigator.onForbidden = null;
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp(
        title: 'AutoHub Admin',
        theme: AdminTheme.light(),
        navigatorKey: AuthNavigator.navigatorKey,
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthUnknown || state is AuthLoading) {
              return const _SplashGate();
            }
            if (state is AuthFailure || state is AuthUnauthenticated) {
              return const LoginPage();
            }
            if (state is AuthAccessDenied) {
              return AccessDeniedPage(email: state.user.email);
            }
            if (state is AuthAuthenticated) {
              return MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) =>
                        DashboardBloc(widget.deps.dashboardRepository)
                          ..add(const DashboardRequested()),
                  ),
                  BlocProvider(create: (_) => UsersBloc(widget.deps.usersRepository)),
                  BlocProvider(create: (_) => SubscriptionsBloc(widget.deps.subscriptionsApi)),
                  BlocProvider(create: (_) => TransactionsBloc(widget.deps.transactionsApi)),
                ],
                child: AdminShell(userEmail: state.user.email),
              );
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}

class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forbidden')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  message.isEmpty ? 'This action is not allowed for your account.' : message,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashGate extends StatelessWidget {
  const _SplashGate();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
