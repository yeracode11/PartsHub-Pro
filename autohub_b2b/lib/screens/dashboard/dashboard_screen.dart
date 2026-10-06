import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_bloc.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_event.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_state.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/widgets/service_reminders_widget.dart';
import 'package:autohub_b2b/widgets/unauthorized_placeholder.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем данные при открытии экрана
    context.read<DashboardBloc>().add(DashboardLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardError) {
            if (state.isForbidden) {
              return UnauthorizedPlaceholder(
                message: state.message,
                isForbidden: false,
              );
            }
            if (state.isOffline) {
              return OfflinePlaceholder(
                onRetry: () =>
                    context.read<DashboardBloc>().add(DashboardLoadRequested()),
              );
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки данных',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<DashboardBloc>().add(
                        DashboardLoadRequested(),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (state is! DashboardLoaded) {
            return const SizedBox();
          }

          return _buildDashboardContent(context, state);
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DashboardLoaded state) {
    final numberFormat = NumberFormat('#,###', 'ru_RU');
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дашборд',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(fontSize: isMobile ? 24 : 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Добро пожаловать в Auto+ Pro',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successGradient.colors[0].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.successGradient.colors[0].withOpacity(
                        0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: AppTheme.successGradient.colors[0],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Онлайн',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.successGradient.colors[0],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: isMobile ? 16 : 32),

          // Статистические карточки
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = isMobile ? 2 : 4;
              final spacing = isMobile ? 12.0 : 24.0;
              final aspectRatio = isMobile ? 1.3 : 1.5;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
                children: [
                  _buildStatCard(
                    context,
                    title: 'Общий доход',
                    value: '${numberFormat.format(state.stats.totalRevenue)} ₸',
                    icon: Icons.attach_money,
                    gradient: AppTheme.primaryGradient,
                    isMobile: isMobile,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Доход за месяц',
                    value:
                        '${numberFormat.format(state.stats.monthlyRevenue)} ₸',
                    icon: Icons.trending_up,
                    gradient: AppTheme.successGradient,
                    isMobile: isMobile,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Товаров на складе',
                    value: '${state.stats.inventoryCount}',
                    icon: Icons.inventory_2,
                    gradient: AppTheme.warningGradient,
                    isMobile: isMobile,
                  ),
                  _buildStatCard(
                    context,
                    title: 'Активные заказы',
                    value: '${state.stats.activeOrdersCount}',
                    icon: Icons.shopping_cart,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    isMobile: isMobile,
                  ),
                ],
              );
            },
          ),

          SizedBox(height: isMobile ? 16 : 32),

          // График продаж и последние заказы
          if (isMobile) ...[
            _buildSalesChart(context, state, isMobile: true),
            const SizedBox(height: 16),
            _buildRecentOrders(context, state, isMobile: true),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildSalesChart(context, state)),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildRecentOrders(context, state)),
              ],
            ),
          ],

          SizedBox(height: isMobile ? 16 : 32),

          // Напоминания о ТО и Популярные товары
          if (!_showServiceReminders(context))
            _buildPopularItems(context, state, isMobile: isMobile)
          else if (isMobile) ...[
            const ServiceRemindersWidget(),
            const SizedBox(height: 16),
            _buildPopularItems(context, state, isMobile: true),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(flex: 1, child: ServiceRemindersWidget()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildPopularItems(context, state)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _showServiceReminders(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is! AuthAuthenticated ||
        authState.user.businessType != BusinessType.dismantler;
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Gradient gradient,
    bool isMobile = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: isMobile ? 12 : 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(
    BuildContext context,
    DashboardLoaded state, {
    bool isMobile = false,
  }) {
    final spots = state.chartData.data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.amount / 1000))
        .toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Продажи',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontSize: isMobile ? 18 : 20),
              ),
              if (!isMobile)
                Row(
                  children: [
                    _buildPeriodButton(
                      context,
                      '7д',
                      '7d',
                      state.currentPeriod == '7d',
                    ),
                    const SizedBox(width: 8),
                    _buildPeriodButton(
                      context,
                      '30д',
                      '30d',
                      state.currentPeriod == '30d',
                    ),
                    const SizedBox(width: 8),
                    _buildPeriodButton(
                      context,
                      '90д',
                      '90d',
                      state.currentPeriod == '90d',
                    ),
                  ],
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPeriodButton(
                    context,
                    '7д',
                    '7d',
                    state.currentPeriod == '7d',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton(
                    context,
                    '30д',
                    '30d',
                    state.currentPeriod == '30d',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPeriodButton(
                    context,
                    '90д',
                    '90d',
                    state.currentPeriod == '90d',
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 16 : 24),
          SizedBox(
            height: isMobile ? 200 : 300,
            child: spots.isEmpty
                ? const Center(child: Text('Нет данных'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 50,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: AppTheme.borderColor,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}k',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (spots.length / 6).ceilToDouble(),
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >=
                                  state.chartData.data.length) {
                                return const Text('');
                              }
                              final date = DateTime.parse(
                                state.chartData.data[value.toInt()].date,
                              );
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${date.day}/${date.month}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          gradient: AppTheme.primaryGradient,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: AppTheme.primaryGradient.colors
                                  .map((c) => c.withOpacity(0.1))
                                  .toList(),
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(
    BuildContext context,
    String label,
    String period,
    bool isSelected,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<DashboardBloc>().add(
            DashboardChartPeriodChanged(period),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders(
    BuildContext context,
    DashboardLoaded state, {
    bool isMobile = false,
  }) {
    final orders = state.recentOrders;
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final money = NumberFormat('#,###', 'ru_RU');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Последние заказы',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            Text(
              'Заказов пока нет',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            )
          else
            ...orders.map((order) {
              final customerName = order.customer?['name']?.toString();
              final subtitle = [
                if (customerName != null && customerName.isNotEmpty)
                  customerName,
                dateFormat.format(order.createdAt),
                _orderStatusLabel(order.status),
              ].join(' · ');
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.orderNumber ?? '#${order.id}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${money.format(order.total)} ₸',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _orderStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Завершен';
      case 'processing':
        return 'В работе';
      case 'cancelled':
        return 'Отменен';
      case 'ready':
        return 'Готов';
      case 'reserved':
        return 'Бронь';
      default:
        return 'Ожидание';
    }
  }

  Widget _buildPopularItems(
    BuildContext context,
    DashboardLoaded state, {
    bool isMobile = false,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Популярные товары',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (state.popularItems.isEmpty)
            Text(
              'Продаж пока нет',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            )
          else if (isMobile)
            ...state.popularItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Продано ${item.soldCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${NumberFormat('#,###', 'ru_RU').format(item.price)} ₸',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Название',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Продано',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Цена',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                ...state.popularItems.map((item) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('${item.soldCount}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${NumberFormat('#,###', 'ru_RU').format(item.price)} ₸',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
        ],
      ),
    );
  }
}
