import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/screens/auth/login_screen.dart';

/// Если пользователь не вошёл — открывает экран входа. Возвращает true, если после этого состояние авторизовано.
Future<bool> ensureAuthenticated(BuildContext context) async {
  if (!context.mounted) return false;
  if (context.read<AuthBloc>().state is AuthAuthenticated) {
    return true;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => const LoginScreen(),
    ),
  );
  if (!context.mounted) return false;
  return context.read<AuthBloc>().state is AuthAuthenticated;
}
