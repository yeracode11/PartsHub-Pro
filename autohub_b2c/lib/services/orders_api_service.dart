import 'package:dio/dio.dart';
import '../models/product_model.dart';
import 'api_client.dart';

class OrdersApiService {
  final ApiClient _apiClient;

  OrdersApiService(this._apiClient);

  // Получить последние заказы
  Future<List<Order>> getRecentOrders({int limit = 5}) async {
    try {
      final response = await _apiClient.get(
        '/orders/recent',
        queryParameters: {'limit': limit},
      );

      final data = response.data as List<dynamic>;
      return data.map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      // Если API недоступен, используем моковые данные
      print('API недоступен, используем моковые данные: $e');
      return _getMockRecentOrders(limit);
    }
  }

  // Получить все заказы пользователя
  Future<List<Order>> getUserOrders() async {
    try {
      final response = await _apiClient.get('/orders');
      final data = response.data as List<dynamic>;
      return data.map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      // Fallback to mock data
      return _getMockUserOrders();
    }
  }

  // Получить заказ по ID
  Future<Order> getOrder(String orderId) async {
    try {
      final response = await _apiClient.get('/orders/$orderId');
      return Order.fromJson(response.data);
    } catch (e) {
      // Fallback to mock data
      return _getMockOrder(orderId);
    }
  }

  // Создать новый заказ
  Future<Order> createOrder({
    required List<OrderItem> items,
    required String shippingAddress,
    String? notes,
  }) async {
    try {
      final orderData = {
        'items': items.map((item) => {
          'productId': item.productId,
          'quantity': item.quantity,
          'price': item.price,
        }).toList(),
        'shippingAddress': shippingAddress,
        'notes': notes,
      };

      final response = await _apiClient.post('/orders', data: orderData);
      return Order.fromJson(response.data);
    } catch (e) {
      throw Exception('Не удалось создать заказ: $e');
    }
  }

  // Отменить заказ
  Future<void> cancelOrder(String orderId) async {
    try {
      await _apiClient.put('/orders/$orderId/cancel');
    } catch (e) {
      throw Exception('Не удалось отменить заказ: $e');
    }
  }

  // Mock data для fallback
  List<Order> _getMockRecentOrders(int limit) {
    final orders = _getMockUserOrders();
    return orders.take(limit).toList();
  }

  List<Order> _getMockUserOrders() {
    final now = DateTime.now();
    return [
      Order(
        id: 1,
        orderNumber: 'ORD-2025-001',
        customerId: 1,
        items: [
          OrderItem(
            id: 1,
            productId: 1,
            productName: 'Фары передние LED Toyota Camry',
            productImage: 'https://via.placeholder.com/100x100',
            price: 45000,
            quantity: 1,
            total: 45000,
          ),
        ],
        totalAmount: 45000,
        status: 'processing',
        paymentStatus: 'paid',
        shippingAddress: 'Алматы, ул. Абая 123',
        notes: 'Доставить до 18:00',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
      Order(
        id: 2,
        orderNumber: 'ORD-2025-002',
        customerId: 1,
        items: [
          OrderItem(
            id: 2,
            productId: 2,
            productName: 'Масло моторное синтетическое 5W-30',
            productImage: 'https://via.placeholder.com/100x100',
            price: 12000,
            quantity: 2,
            total: 24000,
          ),
          OrderItem(
            id: 3,
            productId: 4,
            productName: 'Фильтр воздушный BMW X5',
            productImage: 'https://via.placeholder.com/100x100',
            price: 8000,
            quantity: 1,
            total: 8000,
          ),
        ],
        totalAmount: 32000,
        status: 'shipped',
        paymentStatus: 'paid',
        shippingAddress: 'Алматы, ул. Абая 123',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Order(
        id: 3,
        orderNumber: 'ORD-2025-003',
        customerId: 1,
        items: [
          OrderItem(
            id: 4,
            productId: 3,
            productName: 'Тормозные колодки передние Honda Accord',
            productImage: 'https://via.placeholder.com/100x100',
            price: 25000,
            quantity: 1,
            total: 25000,
          ),
        ],
        totalAmount: 25000,
        status: 'delivered',
        paymentStatus: 'paid',
        shippingAddress: 'Алматы, ул. Абая 123',
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }

  Order _getMockOrder(String orderId) {
    final orders = _getMockUserOrders();
    final order = orders.firstWhere(
      (o) => o.id.toString() == orderId,
      orElse: () => orders.first,
    );
    return order;
  }
}
