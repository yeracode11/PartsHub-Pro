import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/models/order_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/services/offline_queue.dart';

class OrdersRepository {
  final AppDatabase _db;
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  OrdersRepository(this._db);

  Future<List<OrderModel>> getOrders() async {
    List<OrderModel> orders;
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get('/api/orders');
        final List<dynamic> data = response.data;
        final raw = data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        orders = raw.map(OrderModel.fromJson).toList();
        await _cacheOrders(orders);
        await OfflineQueue().writeList('orders', raw);
      } catch (e) {
        debugPrint('[OrdersRepo] API failed, falling back to cache: $e');
        orders = await _ordersFromCache();
        if (orders.isEmpty) rethrow;
      }
    } else {
      orders = await _ordersFromCache();
    }
    return _mergePending(orders);
  }

  bool get isOffline => !_connectivity.isOnline;

  Future<List<OrderModel>> _ordersFromCache() async {
    final raw = await OfflineQueue().readList('orders');
    if (raw != null && raw.isNotEmpty) {
      final parsed = <OrderModel>[];
      for (final json in raw) {
        try {
          parsed.add(OrderModel.fromJson(json));
        } catch (e) {
          debugPrint('[OrdersRepo] Skip cached order: $e');
        }
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return _getFromCache();
  }

  Future<List<OrderModel>> _mergePending(List<OrderModel> orders) async {
    final merged = List<OrderModel>.of(orders);
    for (final json in await OfflineQueue().snapshots('order')) {
      try {
        final pending = OrderModel.fromJson(json);
        final index = merged.indexWhere((order) => order.id == pending.id);
        if (index >= 0) {
          merged[index] = pending;
        } else {
          merged.insert(0, pending);
        }
      } catch (e) {
        debugPrint('[OrdersRepo] Skip pending order: $e');
      }
    }

    for (final json in await OfflineQueue().snapshots('payment')) {
      _applyPayment(merged, json);
    }
    return merged;
  }

  void _applyPayment(List<OrderModel> orders, Map<String, dynamic> snapshot) {
    final rawId = snapshot['orderId'];
    final orderId = rawId is int ? rawId : int.tryParse('$rawId');
    if (orderId == null) return;
    final index = orders.indexWhere((order) => order.id == orderId);
    if (index < 0) return;

    final order = orders[index];
    final payments = List<OrderPaymentModel>.of(order.payments);
    if (snapshot['remove'] == true) {
      final paymentId = snapshot['paymentId'];
      payments.removeWhere((payment) => payment.id.toString() == '$paymentId');
    } else if (snapshot['payment'] is Map) {
      payments.add(
        OrderPaymentModel.fromJson(
          Map<String, dynamic>.from(snapshot['payment'] as Map),
        ),
      );
    }

    final paid = payments.fold<double>(0, (sum, payment) => sum + payment.amount);
    final due = order.total - paid;
    final status = paid <= 0
        ? 'unpaid'
        : due <= 0.009
            ? 'paid'
            : 'partial';
    orders[index] = order.copyWith(
      payments: payments,
      paidAmount: paid,
      dueAmount: due < 0 ? 0 : due,
      paymentStatus: status,
    );
  }

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
