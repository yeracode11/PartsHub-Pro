import 'package:dio/dio.dart';
import 'api_client.dart';

class DashboardApiService {
  final ApiClient _apiClient;

  DashboardApiService(this._apiClient);

  // Получить статистику дашборда
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _apiClient.get('/dashboard/stats');
      return response.data;
    } catch (e) {
      // Если API недоступен, используем моковые данные
      print('API недоступен, используем моковые данные: $e');
      return _getMockStats();
    }
  }

  // Получить график продаж
  Future<List<Map<String, dynamic>>> getSalesChart({String period = '7d'}) async {
    try {
      final response = await _apiClient.get(
        '/dashboard/sales-chart',
        queryParameters: {'period': period},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      // Если API недоступен, используем моковые данные
      print('API недоступен, используем моковые данные: $e');
      return _getMockSalesChart(period);
    }
  }

  // Моковые данные для статистики
  Map<String, dynamic> _getMockStats() {
    return {
      'totalOrders': 156,
      'totalRevenue': 2450000,
      'totalCustomers': 89,
      'totalProducts': 1247,
      'ordersThisMonth': 23,
      'revenueThisMonth': 450000,
      'newCustomersThisMonth': 12,
      'topSellingCategory': 'Двигатель',
    };
  }

  // Моковые данные для графика продаж
  List<Map<String, dynamic>> _getMockSalesChart(String period) {
    final now = DateTime.now();
    final days = period == '7d' ? 7 : period == '30d' ? 30 : 90;
    
    return List.generate(days, (index) {
      final date = now.subtract(Duration(days: days - index - 1));
      return {
        'date': date.toIso8601String().split('T')[0],
        'sales': 15000 + (index * 2000) + (index % 3 == 0 ? 5000 : 0),
        'orders': 3 + (index % 4),
      };
    });
  }
}
