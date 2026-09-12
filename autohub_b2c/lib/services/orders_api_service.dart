import '../models/product_model.dart';
import 'api_client.dart';

class OrdersApiService {
  final ApiClient _apiClient;

  OrdersApiService(this._apiClient);

  Future<List<Order>> getRecentOrders({int limit = 5}) async {
    final response = await _apiClient.get(
      '/orders/recent',
      queryParameters: {'limit': limit},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((json) => Order.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<Order>> getUserOrders() async {
    final response = await _apiClient.get('/b2c/orders');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => Order.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<Order> getOrder(String orderId) async {
    final orders = await getUserOrders();
    return orders.firstWhere(
      (o) => o.id.toString() == orderId,
      orElse: () => throw Exception('Заказ $orderId не найден'),
    );
  }

  Future<Order> createOrder({
    required List<OrderItem> items,
    required String shippingAddress,
    String? notes,
    String? organizationId,
  }) async {
    final orderData = {
      'items': items
          .map((item) => {
                'itemId': item.productId,
                'quantity': item.quantity,
              })
          .toList(),
      'notes': notes,
      'shippingAddress': shippingAddress,
      if (organizationId != null) 'organizationId': organizationId,
    };

    final response = await _apiClient.post('/b2c/orders', data: orderData);
    final responseData = response.data['data'];
    if (responseData is List && responseData.isNotEmpty) {
      return Order.fromJson(Map<String, dynamic>.from(responseData[0]));
    }
    return Order.fromJson(Map<String, dynamic>.from(responseData as Map));
  }

  Future<void> cancelOrder(String orderId) async {
    await _apiClient.put('/orders/$orderId/cancel');
  }
}
