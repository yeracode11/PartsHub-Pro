import 'package:equatable/equatable.dart';

import '../../subscriptions/data/subscriptions_api.dart';
import '../../transactions/data/transactions_api.dart';
import '../../users/data/users_api.dart';

class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.revenueLast30d,
    required this.chartLabels,
    required this.chartValues,
  });

  final int totalUsers;
  final int activeSubscriptions;
  final double revenueLast30d;
  final List<String> chartLabels;
  final List<double> chartValues;

  @override
  List<Object?> get props =>
      [totalUsers, activeSubscriptions, revenueLast30d, chartLabels, chartValues];
}

/// Aggregates lightweight metrics from existing list endpoints (no admin dashboard route required).
class DashboardRepository {
  DashboardRepository({
    required UsersApi usersApi,
    required SubscriptionsApi subscriptionsApi,
    required TransactionsApi transactionsApi,
  })  : _usersApi = usersApi,
        _subscriptionsApi = subscriptionsApi,
        _transactionsApi = transactionsApi;

  final UsersApi _usersApi;
  final SubscriptionsApi _subscriptionsApi;
  final TransactionsApi _transactionsApi;

  Future<DashboardSnapshot> loadOverview() async {
    final usersPage = await _usersApi.listUsers(page: 1, pageSize: 5000, search: null);
    final subs = await _subscriptionsApi.listSubscriptions();

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    final txs = await _transactionsApi.listTransactions(from: from, to: now);

    final activeSubs = subs.where((s) => s.isActive).length;
    final revenue = txs.fold<double>(0, (sum, t) => sum + (t.amount ?? 0));

    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today.subtract(const Duration(days: 6));
    final labels = List.generate(7, (i) {
      final d = windowStart.add(Duration(days: i));
      return '${d.month}/${d.day}';
    });
    final buckets = List<double>.filled(7, 0);

    for (final t in txs) {
      final dt = t.createdAt;
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      final index = day.difference(windowStart).inDays;
      if (index >= 0 && index <= 6) {
        buckets[index] += t.amount ?? 0;
      }
    }

    final chartLabels = List<String>.from(labels);
    final chartValues = List<double>.from(buckets);

    return DashboardSnapshot(
      totalUsers: usersPage.total,
      activeSubscriptions: activeSubs,
      revenueLast30d: revenue,
      chartLabels: chartLabels,
      chartValues: chartValues,
    );
  }
}
