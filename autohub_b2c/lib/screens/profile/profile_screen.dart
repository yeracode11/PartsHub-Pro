import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/design/app_spacing.dart';
import '../../widgets/app_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthLoading) return const LoadingView();
            if (state is! AuthAuthenticated) {
              return const EmptyStateView(
                icon: Icons.person_outline_rounded,
                title: 'Войдите в аккаунт',
                subtitle: 'Авторизация нужна для профиля и заказов',
              );
            }

            final user = state.customer;
            return ScreenLayout(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const PageHeader(title: 'Профиль'),
                  AppCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ActionRow(
                    icon: Icons.home_outlined,
                    title: 'Главная',
                    onTap: () => context.go('/garage'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ActionRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Заказы',
                    onTap: () => context.go('/orders'),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        context.go('/login');
                      },
                      child: const Text('Выйти'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
