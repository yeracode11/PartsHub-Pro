import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import '../features/subscriptions/presentation/pages/subscriptions_page.dart';
import '../features/transactions/presentation/pages/transactions_page.dart';
import '../features/users/presentation/pages/users_page.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.userEmail});

  final String userEmail;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoHub Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(widget.userEmail, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.subscriptions_outlined),
                selectedIcon: Icon(Icons.subscriptions),
                label: Text('Subscriptions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Transactions'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                DashboardPage(),
                UsersPage(),
                SubscriptionsPage(),
                TransactionsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
