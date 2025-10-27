import 'package:autohub_b2b/services/api/base_api_service.dart';
import 'package:autohub_b2b/models/dashboard_stats_model.dart';
import 'package:autohub_b2b/models/order_model.dart';

/// API сервис для работы с дашбордом
/// 
/// ВАЖНО: Бэкенд запущен на http://78.140.246.83:3000
/// Убедитесь что NestJS сервер запущен: cd autohub-backend && npm run start:dev
class DashboardApiService extends BaseApiService {
  // ✅ Бэкенд готов! Используем реальные данные
  static const bool useMockData = false;
  /// Получить статистику дашборда
  Future<DashboardStats> getStats() async {
    // TODO: Удалить mock данные после подключения бэкенда
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 500)); // Имитация задержки сети
      return DashboardStats(
        totalRevenue: 2847000,
        monthlyRevenue: 1234000,
        inventoryCount: 1247,
        activeOrdersCount: 356,
        period: DateTime.now().toString().substring(0, 7),
      );
    }
    
    try {
      final response = await get<Map<String, dynamic>>('/dashboard/stats');
      return DashboardStats.fromJson(response);
    } catch (e) {
      print('Error getting dashboard stats: $e');
      // Возвращаем пустую статистику при ошибке
      return DashboardStats.empty();
    }
  }

  /// Получить данные графика продаж
  /// [period] - период: '7d', '30d', '90d'
  Future<SalesChartData> getSalesChart({String period = '7d'}) async {
    // TODO: Удалить mock данные после подключения бэкенда
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Генерируем данные в зависимости от периода
      final days = period == '7d' ? 7 : (period == '30d' ? 30 : 90);
      final dataPoints = List.generate(days, (index) {
        final date = DateTime.now().subtract(Duration(days: days - index - 1));
        final amount = 120000 + (index * 5000) + (index % 3 * 20000);
        return SalesDataPoint(
          date: date.toString().substring(0, 10),
          amount: amount.toDouble(),
        );
      });
      
      return SalesChartData(period: period, data: dataPoints);
    }
    
    try {
      final response = await get<Map<String, dynamic>>(
        '/dashboard/sales-chart',
        queryParameters: {'period': period},
      );
      return SalesChartData.fromJson(response);
    } catch (e) {
      print('Error getting sales chart: $e');
      // Возвращаем пустой график при ошибке
      return SalesChartData.empty();
    }
  }

  /// Получить последние заказы
  /// [limit] - количество заказов
  Future<List<OrderModel>> getRecentOrders({int limit = 5}) async {
    // TODO: Удалить mock данные после подключения бэкенда
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      
      return List.generate(limit, (index) {
        return OrderModel(
          id: index + 1,
          orderNumber: 'ORD-2025-${(index + 1).toString().padLeft(3, '0')}',
          customerId: 1,
          total: 450000.0 + (index * 50000.0),
          status: index == 0 ? 'processing' : 'pending',
          paymentStatus: 'pending',
          notes: null,
          synced: false,
          createdAt: DateTime.now().subtract(Duration(hours: index * 2)),
          updatedAt: DateTime.now().subtract(Duration(hours: index * 2)),
        );
      });
    }
    
    try {
      final response = await get<Map<String, dynamic>>(
        '/orders/recent',
        queryParameters: {'limit': limit},
      );
      
      final orders = (response['orders'] as List?)
              ?.map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      
      return orders;
    } catch (e) {
      print('Error getting recent orders: $e');
      // Возвращаем пустой список при ошибке
      return [];
    }
  }

  /// Получить популярные товары
  /// [limit] - количество товаров
  Future<List<PopularItem>> getPopularItems({int limit = 5}) async {
    // TODO: Удалить mock данные после подключения бэкенда
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 350));
      
      final items = [
        PopularItem(id: 1, name: 'Фары передние LED Toyota', soldCount: 2847, price: 45000),
        PopularItem(id: 2, name: 'Двигатель Honda 2.0', soldCount: 1523, price: 350000),
        PopularItem(id: 3, name: 'КПП автомат Mazda', soldCount: 1456, price: 180000),
        PopularItem(id: 4, name: 'Бампер передний BMW', soldCount: 1201, price: 35000),
        PopularItem(id: 5, name: 'Капот Mercedes', soldCount: 987, price: 55000),
      ];
      
      return items.take(limit).toList();
    }
    
    try {
      final response = await get<Map<String, dynamic>>(
        '/items/popular',
        queryParameters: {'limit': limit},
      );
      
      final items = (response['items'] as List?)
              ?.map((e) => PopularItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      
      return items;
    } catch (e) {
      print('Error getting popular items: $e');
      // Возвращаем пустой список при ошибке
      return [];
    }
  }
}

