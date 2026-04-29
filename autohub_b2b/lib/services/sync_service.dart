import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  late AppDatabase _db;
  final ApiClient _apiClient = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isSyncing = false;
  final _syncStateController = StreamController<SyncState>.broadcast();
  Stream<SyncState> get onSyncStateChanged => _syncStateController.stream;

  StreamSubscription<bool>? _connectivitySub;

  SyncService._internal();

  void init(AppDatabase db) {
    _db = db;
    _connectivitySub = _connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        debugPrint('[Sync] Connection restored, starting sync...');
        syncAll();
      }
    });
  }

  /// Push local changes (SyncQueue) to the server, then pull fresh data
  Future<void> syncAll() async {
    if (_isSyncing || !_connectivity.isOnline) return;

    final token = await SecureStorageService().getAuthToken();
    if (token == null || token.trim().isEmpty) {
      debugPrint('[Sync] Skipped: no JWT yet (routes require Bearer token)');
      return;
    }

    _isSyncing = true;
    _syncStateController.add(SyncState.syncing);
    debugPrint('[Sync] Starting full sync...');

    try {
      await _pushChanges();
      await _pullItems();
      await _pullOrders();
      await _pullCustomers();
      _syncStateController.add(SyncState.idle);
      debugPrint('[Sync] Sync complete.');
    } catch (e) {
      debugPrint('[Sync] Error during sync: $e');
      _syncStateController.add(SyncState.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Process the SyncQueue: push pending local writes to the server
  Future<void> _pushChanges() async {
    final pending = await _db.getUnsyncedItems();
    if (pending.isEmpty) return;
    debugPrint('[Sync] Pushing ${pending.length} pending changes...');

    for (final item in pending) {
      try {
        final data = jsonDecode(item.data) as Map<String, dynamic>;
        final path = _apiPath(item.syncTableName, item.recordId);

        switch (item.operation) {
          case 'create':
            await _apiClient.dio.post(path, data: data);
            break;
          case 'update':
            await _apiClient.dio.put('$path/${item.recordId}', data: data);
            break;
          case 'delete':
            await _apiClient.dio.delete('$path/${item.recordId}');
            break;
        }

        await _db.markSynced(item.id);
      } catch (e) {
        debugPrint('[Sync] Failed to push ${item.syncTableName}/${item.recordId}: $e');
      }
    }
  }

  String _apiPath(String tableName, int recordId) {
    switch (tableName) {
      case 'items':
        return '/api/items';
      case 'orders':
        return '/api/orders';
      case 'customers':
        return '/api/customers';
      default:
        return '/api/$tableName';
    }
  }

  /// Pull items from server and cache locally
  Future<void> _pullItems() async {
    try {
      final response = await _apiClient.dio.get('/api/items');
      final List<dynamic> data = response.data;

      await _db.batch((batch) async {
        batch.deleteAll(_db.items);
        for (final json in data) {
          batch.insert(
            _db.items,
            ItemsCompanion.insert(
              id: Value(json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0),
              name: json['name'] ?? 'Без названия',
              category: json['category'] ?? '',
              sku: Value(json['sku'] as String?),
              price: (json['price'] is num ? json['price'].toDouble() : double.tryParse(json['price']?.toString() ?? '') ?? 0.0),
              quantity: Value(json['quantity'] is int ? json['quantity'] : 0),
              condition: json['condition'] ?? 'new',
              description: Value(json['description'] as String?),
              imageUrl: Value(json['imageUrl'] as String?),
              synced: const Value(true),
            ),
          );
        }
      });
      debugPrint('[Sync] Pulled ${data.length} items');
    } catch (e) {
      debugPrint('[Sync] Failed to pull items: $e');
    }
  }

  /// Pull orders from server and cache locally
  Future<void> _pullOrders() async {
    try {
      final response = await _apiClient.dio.get('/api/orders');
      final List<dynamic> data = response.data;

      await _db.batch((batch) async {
        batch.deleteAll(_db.orders);
        for (final json in data) {
          batch.insert(
            _db.orders,
            OrdersCompanion.insert(
              id: Value(json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0),
              customerId: Value(json['customerId'] as int?),
              total: Value(json['total'] is num ? json['total'].toDouble() : 0.0),
              status: json['status'] ?? 'pending',
              paymentStatus: json['paymentStatus'] ?? 'unpaid',
              notes: Value(json['notes'] as String?),
              synced: const Value(true),
            ),
          );
        }
      });
      debugPrint('[Sync] Pulled ${data.length} orders');
    } catch (e) {
      debugPrint('[Sync] Failed to pull orders: $e');
    }
  }

  /// Pull customers from server and cache locally
  Future<void> _pullCustomers() async {
    try {
      final response = await _apiClient.dio.get('/api/customers');
      final List<dynamic> data = response.data;

      await _db.batch((batch) async {
        batch.deleteAll(_db.customers);
        for (final json in data) {
          batch.insert(
            _db.customers,
            CustomersCompanion.insert(
              id: Value(json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0),
              name: json['name'] ?? '',
              phone: json['phone'] ?? '',
              email: Value(json['email'] as String?),
              carBrand: Value(json['carBrand'] as String?),
              carModel: Value(json['carModel'] as String?),
              carYear: Value(json['carYear'] as String?),
              vin: Value(json['vin'] as String?),
              notes: Value(json['notes'] as String?),
              synced: const Value(true),
            ),
          );
        }
      });
      debugPrint('[Sync] Pulled ${data.length} customers');
    } catch (e) {
      debugPrint('[Sync] Failed to pull customers: $e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncStateController.close();
  }
}

enum SyncState { idle, syncing, error }
