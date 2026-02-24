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
  Map<String, dynamic>? abcXyzSummary;
  List<Map<String, dynamic>> abcXyzItems = [];
  List<Map<String, dynamic>> staffReportItems = [];

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

      // ABC/XYZ аналитика
      final abcXyzResponse = await dio.get('/api/dashboard/abc-xyz');
      abcXyzSummary = abcXyzResponse.data['summary'];
      abcXyzItems = List<Map<String, dynamic>>.from(
        abcXyzResponse.data['items'] ?? [],
      );

      // Отчеты по персоналу
      final staffReportResponse =
          await dio.get('/api/dashboard/staff-report?period=$selectedPeriod');
      staffReportItems = List<Map<String, dynamic>>.from(
        staffReportResponse.data['items'] ?? [],
      );

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
    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Заголовок
          Container(
            padding: EdgeInsets.all(padding),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Аналитика',
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                              fontSize: isMobile ? 24 : 28,
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Детальная аналитика продаж и товаров',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadAnalytics,
                      tooltip: 'Обновить',
                    ),
                  ],
                ),
                if (isMobile) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '7d', label: Text('7д')),
                      ButtonSegment(value: '30d', label: Text('30д')),
                      ButtonSegment(value: '90d', label: Text('90д')),
                    ],
                    selected: {selectedPeriod},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        selectedPeriod = newSelection.first;
                      });
                      _loadAnalytics();
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
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
                    ],
                  ),
                ],
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

    final isMobile = MediaQuery.of(context).size.width < 768;
    final padding = isMobile ? 16.0 : 24.0;
    final spacing = isMobile ? 16.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ключевые метрики
          if (advancedAnalytics != null) _buildKeyMetrics(isMobile: isMobile),
          SizedBox(height: spacing),

          // График продаж
          if (salesChart != null) _buildSalesChart(isMobile: isMobile),
          SizedBox(height: spacing),

          // Две колонки
          if (isMobile) ...[
            _buildTopSellingItems(isMobile: true),
            SizedBox(height: spacing),
            _buildLowStockItems(isMobile: true),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTopSellingItems()),
                SizedBox(width: spacing),
                Expanded(child: _buildLowStockItems()),
              ],
            ),
          ],
          SizedBox(height: spacing),

          if (abcXyzSummary != null || abcXyzItems.isNotEmpty)
            _buildAbcXyzCard(isMobile: isMobile),
          if (abcXyzSummary != null || abcXyzItems.isNotEmpty)
            SizedBox(height: spacing),

          if (staffReportItems.isNotEmpty) _buildStaffReportCard(isMobile: isMobile),
          if (staffReportItems.isNotEmpty) SizedBox(height: spacing),

          // Продажи по категориям
          if (salesByCategory.isNotEmpty) _buildSalesByCategory(),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics({bool isMobile = false}) {
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

    final spacing = isMobile ? 12.0 : 16.0;

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricCard(
                'Выручка',
                currencyFormatter.format(revenue['current']),
                revenue['change']?.toDouble() ?? 0.0,
                Icons.attach_money,
                AppTheme.primaryColor,
                isMobile: true,
              )),
              SizedBox(width: spacing),
              Expanded(child: _buildMetricCard(
                'Заказы',
                '${orders['current']}',
                orders['change']?.toDouble() ?? 0.0,
                Icons.shopping_bag,
                Colors.orange,
                isMobile: true,
              )),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(child: _buildMetricCard(
                'Средний чек',
                currencyFormatter.format(avgOrder['current']),
                avgOrder['change']?.toDouble() ?? 0.0,
                Icons.receipt,
                Colors.green,
                isMobile: true,
              )),
              SizedBox(width: spacing),
              Expanded(child: _buildMetricCard(
                'Прибыль',
                currencyFormatter.format(profit['amount']),
                profit['margin']?.toDouble() ?? 0.0,
                Icons.trending_up,
                Colors.purple,
                isPercent: true,
                isMobile: true,
              )),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildMetricCard(
          'Выручка',
          currencyFormatter.format(revenue['current']),
          revenue['change']?.toDouble() ?? 0.0,
          Icons.attach_money,
          AppTheme.primaryColor,
        )),
        SizedBox(width: spacing),
        Expanded(child: _buildMetricCard(
          'Заказы',
          '${orders['current']}',
          orders['change']?.toDouble() ?? 0.0,
          Icons.shopping_bag,
          Colors.orange,
        )),
        SizedBox(width: spacing),
        Expanded(child: _buildMetricCard(
          'Средний чек',
          currencyFormatter.format(avgOrder['current']),
          avgOrder['change']?.toDouble() ?? 0.0,
          Icons.receipt,
          Colors.green,
        )),
        SizedBox(width: spacing),
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
    bool isMobile = false,
  }) {
    final isPositive = change >= 0;
    final changeText = isPercent
        ? '${change.toStringAsFixed(1)}%'
        : '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
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

  Widget _buildSalesChart({bool isMobile = false}) {
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
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Продажи по дням',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 18 : 20,
                    ),
                  ),
                ),
                if (!isMobile)
                  Flexible(
                    child: Container(
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
                          Flexible(
                            child: Text(
                              'Макс: ${currencyFormatter.format(maxAmount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: isMobile ? 8 : 8),
            if (isMobile)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildStatItem('Среднее', currencyFormatter.format(avgAmount), Colors.blue, isMobile: true, inWrap: true),
                  _buildStatItem('Макс', currencyFormatter.format(maxAmount), Colors.green, isMobile: true, inWrap: true),
                  _buildStatItem('Мин', currencyFormatter.format(minAmount), Colors.orange, isMobile: true, inWrap: true),
                ],
              )
            else
              Row(
                children: [
                  _buildStatItem('Среднее', currencyFormatter.format(avgAmount), Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatItem('Макс', currencyFormatter.format(maxAmount), Colors.green),
                  const SizedBox(width: 16),
                  _buildStatItem('Мин', currencyFormatter.format(minAmount), Colors.orange),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 24),
            SizedBox(
              height: isMobile ? 320 : 350,
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
                        reservedSize: isMobile ? 45 : 60,
                        interval: maxAmount > 0 ? maxAmount / 5 : 1000,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return Text(
                              '0',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                color: Colors.grey,
                              ),
                            );
                          }
                          return Padding(
                            padding: EdgeInsets.only(right: isMobile ? 4 : 8),
                            child: Text(
                              formatYAxis(value),
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
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
                        reservedSize: isMobile ? 25 : 30,
                        interval: interval.toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length && index % interval == 0) {
                            final dateStr = data[index]['date'] as String;
                            final date = DateTime.parse(dateStr);
                            return Padding(
                              padding: EdgeInsets.only(top: isMobile ? 4 : 8),
                              child: Text(
                                '${date.day}.${date.month}',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
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

  Widget _buildStatItem(String label, String value, Color color, {bool isMobile = false, bool inWrap = false}) {
    final container = Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 11 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    // Если используется в Wrap, не оборачиваем в Flexible/Expanded
    if (inWrap) {
      return container;
    }
    
    if (isMobile) {
      return Flexible(child: container);
    }
    return Expanded(child: container);
  }

  Widget _buildTopSellingItems({bool isMobile = false}) {
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
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: AppTheme.primaryColor, size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Топ продаваемых товаров',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
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

  Widget _buildAbcXyzCard({bool isMobile = false}) {
    final summary = abcXyzSummary ?? {};
    final items = abcXyzItems;

    Widget buildTag(String label, int value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          '$label: $value',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 12,
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
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.teal, size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'ABC/XYZ анализ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                buildTag('A', ((summary['A'] ?? 0) as num).toInt(), Colors.green),
                buildTag('B', ((summary['B'] ?? 0) as num).toInt(), Colors.orange),
                buildTag('C', ((summary['C'] ?? 0) as num).toInt(), Colors.redAccent),
                buildTag('X', ((summary['X'] ?? 0) as num).toInt(), Colors.blue),
                buildTag('Y', ((summary['Y'] ?? 0) as num).toInt(), Colors.deepPurple),
                buildTag('Z', ((summary['Z'] ?? 0) as num).toInt(), Colors.grey),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            if (items.isEmpty)
              Text(
                'Нет данных для ABC/XYZ анализа',
                style: TextStyle(color: AppTheme.textSecondary),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final abc = item['abc']?.toString() ?? '-';
                  final xyz = item['xyz']?.toString() ?? '-';
                  final revenue = item['revenue'] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: Text(
                        '$abc/$xyz',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(item['name'] ?? 'Без названия'),
                    subtitle: Text(
                      'Артикул: ${item['sku'] ?? '—'}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: Text(
                      currencyFormatter.format(revenue),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffReportCard({bool isMobile = false}) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₸',
      decimalDigits: 0,
    );

    String roleLabel(String? role) {
      switch (role) {
        case 'owner':
          return 'Владелец';
        case 'manager':
          return 'Менеджер';
        case 'storekeeper':
          return 'Кладовщик';
        case 'worker':
          return 'Сотрудник';
        default:
          return 'Сотрудник';
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.indigo, size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Отчеты по персоналу',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: staffReportItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = staffReportItems[index];
                final ordersCount = (item['ordersCount'] as num?)?.toInt() ?? 0;
                final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
                final avgCheck = (item['avgCheck'] as num?)?.toDouble() ?? 0;
                final conversion = (item['conversion'] as num?)?.toDouble() ?? 0;
                return ListTile(
                  title: Text(item['name'] ?? 'Сотрудник'),
                  subtitle: Text(
                    roleLabel(item['role']?.toString()),
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFormatter.format(revenue),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Заказов: $ordersCount • Ср. чек: ${currencyFormatter.format(avgCheck)} • Оплата: ${(conversion * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildLowStockItems({bool isMobile = false}) {
    if (lowStockItems.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle, size: isMobile ? 40 : 48, color: Colors.green),
                const SizedBox(height: 8),
                Text(
                  'Все товары в наличии',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
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
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: isMobile ? 20 : 24),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Товары с низким остатком',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
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
    final isMobile = MediaQuery.of(context).size.width < 768;
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
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Продажи по категориям',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: isMobile ? 18 : 20,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            if (isMobile) ...[
              // На мобильных: диаграмма сверху, легенда снизу
              AspectRatio(
                aspectRatio: 1.2,
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
                        radius: 80,
                        titleStyle: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                    sectionsSpace: 2,
                    centerSpaceRadius: isMobile ? 30 : 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Легенда
              ...salesByCategory.asMap().entries.map((entry) {
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
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
                                fontSize: 14,
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
            ] else ...[
              // На desktop: диаграмма и легенда рядом
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          ],
        ),
      ),
    );
  }
}
