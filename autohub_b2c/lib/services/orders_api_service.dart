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
      print('📦 Loading user orders from B2C API...');
      final response = await _apiClient.get('/b2c/orders');
      print('📦 B2C API response: ${response.statusCode}');
      
      // B2C API возвращает объект с data
      final responseData = response.data;
      final data = responseData['data'] as List<dynamic>;
      final orders = data.map((json) => Order.fromJson(json)).toList();
      print('✅ Loaded ${orders.length} orders');
      return orders;
    } catch (e) {
      print('❌ Error loading orders from B2C API: $e');
      // Возвращаем пустой список вместо моковых данных
      return [];
    }
  }

  // Получить заказ по ID
  Future<Order> getOrder(String orderId) async {
    try {
      print('📦 Loading order details for ID: $orderId');
      // Получаем все заказы и находим нужный
      final orders = await getUserOrders();
      final order = orders.firstWhere(
        (o) => o.id.toString() == orderId,
        orElse: () => throw Exception('Order not found'),
      );
      print('✅ Found order: ${order.orderNumber}');
      return order;
    } catch (e) {
      print('❌ Error loading order: $e');
      // Fallback to mock data
      return _getMockOrder(orderId);
    }
  }

  // Создать новый заказ
  Future<Order> createOrder({
    required List<OrderItem> items,
    required String shippingAddress,
    String? notes,
    String? organizationId, // Опциональный organizationId для создания заказа в конкретной организации
  }) async {
    try {
      print('📝 Creating B2C order with ${items.length} items...');
      if (organizationId != null) {
        print('📝 Using organizationId: $organizationId');
      }
      
      final orderData = {
        'items': items.map((item) => ({
          'itemId': item.productId,
          'quantity': item.quantity,
        })).toList(),
        'notes': notes,
        'shippingAddress': shippingAddress,
        if (organizationId != null) 'organizationId': organizationId,
      };

      print('📝 B2C Order data: $orderData');
      
      final response = await _apiClient.post('/b2c/orders', data: orderData);
      print('✅ B2C Order created: ${response.statusCode}');
      
      // B2C API может вернуть один заказ или массив заказов (если товары от разных продавцов)
      final responseData = response.data['data'];
      
      // Если это массив заказов, берем первый (или можно обработать все)
      if (responseData is List && responseData.isNotEmpty) {
        print('📦 Multiple orders created (${responseData.length}) for different sellers');
        // Возвращаем первый заказ, но можно обработать все
        return Order.fromJson(responseData[0]);
      }
      
      // Один заказ
      return Order.fromJson(responseData);
    } catch (e) {
      print('❌ Error creating B2C order: $e');
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
