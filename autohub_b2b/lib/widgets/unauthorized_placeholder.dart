import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/core/theme.dart';

/// Виджет-заглушка, который отображается при ошибке 403 (Доступ запрещён).
/// Предлагает пользователю войти в систему.
class UnauthorizedPlaceholder extends StatelessWidget {
  final String? message;

  const UnauthorizedPlaceholder({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Иконка замка
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 28),

            Text(
              'Требуется авторизация',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
            ),

            const SizedBox(height: 12),

            Text(
              message ??
                  'У вас нет доступа к этому разделу.\nПожалуйста, войдите в систему.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
            ),

            const SizedBox(height: 36),

            // Кнопка «Войти»
            SizedBox(
              width: 220,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Разлогиниваем пользователя — AuthWrapper автоматически
                  // перенаправит на LoginScreen
                  context.read<AuthBloc>().add(AuthSignOutRequested());
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  'Войти в систему',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
