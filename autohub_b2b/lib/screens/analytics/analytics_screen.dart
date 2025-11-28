import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/services/api/api_client.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final dio = ApiClient().dio;
  bool isLoading = true;
  String? error;

  // Данные для аналитики
  Map<String, dynamic>? advancedAnalytics;
  List<Map<String, dynamic>> topSellingItems = [];
  List<Map<String, dynamic>> lowStockItems = [];
  List<Map<String, dynamic>> salesByCategory = [];
  Map<String, dynamic>? salesChart;

  String selectedPeriod = '30d';

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // Загружаем расширенную аналитику
      final analyticsResponse = await dio.get('/api/dashboard/advanced');
      advancedAnalytics = analyticsResponse.data;

      // Топ продаваемых товаров
      final topItemsResponse = await dio.get('/api/dashboard/top-selling-items?limit=10');
      topSellingItems = List<Map<String, dynamic>>.from(
        topItemsResponse.data['items'] ?? [],
      );

      // Товары с низким остатком
      final lowStockResponse = await dio.get('/api/dashboard/low-stock-items?threshold=5');
      lowStockItems = List<Map<String, dynamic>>.from(
        lowStockResponse.data['items'] ?? [],
      );

      // Продажи по категориям
      final categorySalesResponse = await dio.get('/api/dashboard/sales-by-category');
      salesByCategory = List<Map<String, dynamic>>.from(
        categorySalesResponse.data['categories'] ?? [],
      );

      // График продаж
      final chartResponse = await dio.get('/api/dashboard/sales-chart?period=$selectedPeriod');
      salesChart = chartResponse.data;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аналитика',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Детальная аналитика продаж и товаров',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Выбор периода для графика
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: '7d', label: Text('7 дней')),
                        ButtonSegment(value: '30d', label: Text('30 дней')),
                        ButtonSegment(value: '90d', label: Text('90 дней')),
                      ],
                      selected: {selectedPeriod},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          selectedPeriod = newSelection.first;
                        });
                        _loadAnalytics();
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadAnalytics,
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Контент
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Ошибка: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ключевые метрики
          if (advancedAnalytics != null) _buildKeyMetrics(),
          const SizedBox(height: 24),

          // График продаж
          if (salesChart != null) _buildSalesChart(),
          const SizedBox(height: 24),

          // Две колонки
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Топ продаваемых товаров
              Expanded(child: _buildTopSellingItems()),
              const SizedBox(width: 24),
              // Товары с низким остатком
              Expanded(child: _buildLowStockItems()),
            ],
          ),
          const SizedBox(height: 24),

          // Продажи по категориям
          if (salesByCategory.isNotEmpty) _buildSalesByCategory(),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    final revenue = advancedAnalytics!['revenue'];
    final orders = advancedAnalytics!['orders'];
    final avgOrder = advancedAnalytics!['avgOrderValue'];
    final profit = advancedAnalytics!['profit'];
    final payments = advancedAnalytics!['payments'];

    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Row(
      children: [
        Expanded(child: _buildMetricCard(
          'Выручка',
          currencyFormatter.format(revenue['current']),
          revenue['change']?.toDouble() ?? 0.0,
          Icons.attach_money,
          AppTheme.primaryColor,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          'Заказы',
          '${orders['current']}',
          orders['change']?.toDouble() ?? 0.0,
          Icons.shopping_bag,
          Colors.orange,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          'Средний чек',
          currencyFormatter.format(avgOrder['current']),
          avgOrder['change']?.toDouble() ?? 0.0,
          Icons.receipt,
          Colors.green,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(
          'Прибыль',
          currencyFormatter.format(profit['amount']),
          profit['margin']?.toDouble() ?? 0.0,
          Icons.trending_up,
          Colors.purple,
          isPercent: true,
        )),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    double change,
    IconData icon,
    Color color, {
    bool isPercent = false,
  }) {
    final isPositive = change >= 0;
    final changeText = isPercent
        ? '${change.toStringAsFixed(1)}%'
        : '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        changeText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    final data = salesChart!['data'] as List<dynamic>;
    if (data.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Нет данных о продажах за выбранный период',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    final amounts = data.map((d) => (d['amount'] as num).toDouble()).toList();
    final maxAmount = amounts.reduce((a, b) => a > b ? a : b);
    final minAmount = amounts.reduce((a, b) => a < b ? a : b);
    final avgAmount = amounts.reduce((a, b) => a + b) / amounts.length;

    // Улучшенное форматирование для осей
    String formatYAxis(double value) {
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(1)}М';
      } else if (value >= 1000) {
        return '${(value / 1000).toStringAsFixed(0)}К';
      }
      return value.toStringAsFixed(0);
    }

    // Показываем подписи на оси X не для всех точек, а через интервал
    int getInterval() {
      if (data.length <= 7) return 1;
      if (data.length <= 14) return 2;
      if (data.length <= 30) return 3;
      return 5;
    }

    final interval = getInterval();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Продажи по дням',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            'Макс: ${currencyFormatter.format(maxAmount)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatItem('Среднее', currencyFormatter.format(avgAmount), Colors.blue),
                const SizedBox(width: 16),
                _buildStatItem('Макс', currencyFormatter.format(maxAmount), Colors.green),
                const SizedBox(width: 16),
                _buildStatItem('Мин', currencyFormatter.format(minAmount), Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 350, // Увеличил высоту для лучшей видимости
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: maxAmount > 0 ? maxAmount / 5 : 1000,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: AppTheme.borderColor.withOpacity(0.3),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: maxAmount > 0 ? maxAmount / 5 : 1000,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const Text('0', style: TextStyle(fontSize: 11, color: Colors.grey));
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              formatYAxis(value),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: interval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length && index % interval == 0) {
                            final dateStr = data[index]['date'] as String;
                            final date = DateTime.parse(dateStr);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date.day}.${date.month}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: AppTheme.borderColor,
                      width: 1,
                    ),
                  ),
                  minY: 0,
                  maxY: maxAmount * 1.15, // Немного больше для лучшей видимости
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          final index = touchedSpot.x.toInt();
                          if (index >= 0 && index < data.length) {
                            final dateStr = data[index]['date'] as String;
                            final date = DateTime.parse(dateStr);
                            final amount = touchedSpot.y;
                            return LineTooltipItem(
                              '${date.day}.${date.month}.${date.year}\n${currencyFormatter.format(amount)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                      tooltipRoundedRadius: 8,
                      tooltipPadding: const EdgeInsets.all(12),
                    ),
                    handleBuiltInTouches: true,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['amount'] as num).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppTheme.primaryColor,
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AppTheme.primaryColor,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.3),
                            AppTheme.primaryColor.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems() {
    if (topSellingItems.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Нет данных о продажах',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Топ продаваемых товаров',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topSellingItems.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = topSellingItems[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(item['name'] ?? 'Без названия'),
                  subtitle: Text(
                    'Продано: ${item['quantity']} шт.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormatter.format(item['revenue']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Выручка',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockItems() {
    if (lowStockItems.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  'Все товары в наличии',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Товары с низким остатком',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lowStockItems.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = lowStockItems[index];
                final quantity = item['quantity'] as int;
                final isCritical = quantity == 0;

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isCritical ? Colors.red : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCritical ? Icons.error : Icons.warning,
                      color: isCritical ? Colors.red : Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(item['name'] ?? 'Без названия'),
                  subtitle: Text(
                    item['category'] ?? 'Без категории',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$quantity шт.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isCritical ? Colors.red : Colors.orange,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(item['price']),
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesByCategory() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    final totalRevenue = salesByCategory.fold<double>(
      0,
      (sum, cat) => sum + (cat['revenue'] as num).toDouble(),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Продажи по категориям',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Круговая диаграмма
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: PieChart(
                      PieChartData(
                        sections: salesByCategory.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final colors = [
                            AppTheme.primaryColor,
                            Colors.orange.shade400,
                            Colors.green.shade400,
                            Colors.purple.shade400,
                            Colors.blue.shade400,
                            Colors.red.shade400,
                          ];

                          final percentage = totalRevenue > 0
                              ? ((category['revenue'] as num).toDouble() / totalRevenue) * 100
                              : 0.0;

                          return PieChartSectionData(
                            value: (category['revenue'] as num).toDouble(),
                            title: '${percentage.toStringAsFixed(1)}%',
                            color: colors[index % colors.length],
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Легенда
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: salesByCategory.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final colors = [
                        AppTheme.primaryColor,
                        Colors.orange.shade400,
                        Colors.green.shade400,
                        Colors.purple.shade400,
                        Colors.blue.shade400,
                        Colors.red.shade400,
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category['category'] ?? 'Без категории',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${category['quantity']} шт · ${currencyFormatter.format(category['revenue'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
