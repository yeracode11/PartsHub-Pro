import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    _Tab('/garage', 'Главная', Icons.home_outlined, Icons.home_rounded),
    _Tab('/parts', 'Запчасти', Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
    _Tab('/services', 'Сервис', Icons.build_outlined, Icons.build_rounded),
    _Tab('/orders', 'Заказы', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Tab('/profile', 'Профиль', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  int _indexForLocation(String location) {
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        height: AppSpacing.bottomNavHeight,
        backgroundColor: AppColors.navBar,
        indicatorColor: AppColors.accentMuted,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _Tab(this.path, this.label, this.icon, this.selectedIcon);
}
