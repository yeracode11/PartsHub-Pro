import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/cart/cart_bloc.dart';
import '../blocs/cart/cart_state.dart';
import '../core/constants/app_branding.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../core/navigation/garage_navigation.dart';

/// Боковое меню главной страницы.
class AppSideDrawer extends StatelessWidget {
  const AppSideDrawer({super.key});

  void _navigate(BuildContext context, String path) {
    Navigator.of(context).pop();
    navigateFromGarage(context, path);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppBranding.appName,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is! AuthAuthenticated) {
                  return const SizedBox.shrink();
                }
                final user = state.customer;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    user.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                  horizontal: AppSpacing.sm,
                ),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Главная',
                    onTap: () => _navigate(context, '/garage'),
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Запчасти',
                    onTap: () => _navigate(context, '/parts'),
                  ),
                  _DrawerItem(
                    icon: Icons.build_outlined,
                    label: 'Сервис',
                    onTap: () => _navigate(context, '/services'),
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Заказы',
                    onTap: () => _navigate(context, '/orders'),
                  ),
                  BlocBuilder<CartBloc, CartState>(
                    builder: (context, state) {
                      final count =
                          state is CartLoaded ? state.cart.totalItems : 0;
                      return _DrawerItem(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Корзина',
                        badge: count > 0 ? '$count' : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push('/cart');
                        },
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Профиль',
                    onTap: () => _navigate(context, '/profile'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                badge!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            )
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      onTap: onTap,
    );
  }
}
