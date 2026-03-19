import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/database/database.dart';

class OrdersRepository {
  final AppDatabase _db;
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  OrdersRepository(this._db);

  Future<List<OrderModel>> getOrders() async {
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get('/api/orders');
        final List<dynamic> data = response.data;
        final orders = data.map((j) => OrderModel.fromJson(j)).toList();
        await _cacheOrders(orders);
        return orders;
      } catch (e) {
        debugPrint('[OrdersRepo] API failed, falling back to cache: $e');
        final cached = await _getFromCache();
        if (cached.isNotEmpty) return cached;
        rethrow;
      }
    }
    return _getFromCache();
  }

  bool get isOffline => !_connectivity.isOnline;

  Future<List<OrderModel>> _getFromCache() async {
    final rows = await _db.getAllOrders();
    return rows.map(_mapDriftToModel).toList();
  }

  Future<void> _cacheOrders(List<OrderModel> orders) async {
    try {
      await _db.batch((batch) async {
        batch.deleteAll(_db.orders);
        for (final order in orders) {
          batch.insert(
            _db.orders,
            OrdersCompanion.insert(
              id: Value(order.id ?? 0),
              customerId: Value(order.customerId),
              total: Value(order.total),
              status: order.status,
              paymentStatus: order.paymentStatus,
              notes: Value(order.notes),
              synced: const Value(true),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[OrdersRepo] Cache write failed: $e');
    }
  }

  OrderModel _mapDriftToModel(Order row) {
    return OrderModel(
      id: row.id,
      total: row.total,
      status: row.status,
      paymentStatus: row.paymentStatus,
      notes: row.notes,
      customerId: row.customerId,
      synced: row.synced,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
