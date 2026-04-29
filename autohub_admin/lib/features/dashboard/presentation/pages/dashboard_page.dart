import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../data/dashboard_repository.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        final loading = state is DashboardLoading || state is DashboardInitial;
        final snap = state is DashboardReady ? state.snapshot : null;
        final error = state is DashboardFailure ? state.message : null;

        Widget body;
        if (error != null) {
          body = InlineError(
            message: error,
            onRetry: () => context.read<DashboardBloc>().add(const DashboardRequested()),
          );
        } else if (snap == null) {
          body = loading
              ? const Center(child: CircularProgressIndicator())
              : const EmptyState(title: 'No metrics yet', subtitle: 'Tap refresh to load.');
        } else {
          body = _DashboardBody(snapshot: snap);
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: LoadingOverlay(
            loading: loading && snap == null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () =>
                          context.read<DashboardBloc>().add(const DashboardRequested()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: r'$');
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(
                    title: 'Total users',
                    value: '${snapshot.totalUsers}',
                    icon: Icons.group_outlined,
                  ),
                  _StatCard(
                    title: 'Active subscriptions',
                    value: '${snapshot.activeSubscriptions}',
                    icon: Icons.toggle_on_outlined,
                  ),
                  _StatCard(
                    title: 'Revenue (30d)',
                    value: money.format(snapshot.revenueLast30d),
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Revenue trend (7 days)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= snapshot.chartLabels.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    snapshot.chartLabels[i],
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            spots: [
                              for (var i = 0; i < snapshot.chartValues.length; i++)
                                FlSpot(i.toDouble(), snapshot.chartValues[i]),
                            ],
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
