import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/services/offline_queue.dart';

class ItemsRepository {
  final AppDatabase _db;
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  ItemsRepository(this._db);

  Future<List<ItemModel>> getItems({Map<String, dynamic>? filters}) async {
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get(
          '/api/items',
          queryParameters: filters,
        );
        final List<dynamic> data = response.data;
        final items = data.map((j) => ItemModel.fromJson(j)).toList();
        if (filters == null || filters.isEmpty) await _cacheItems(items);
        return _mergePending(items);
      } catch (e) {
        debugPrint('[ItemsRepo] API failed, falling back to cache: $e');
        final cached = await _getFromCache();
        if (cached.isNotEmpty) return _mergePending(cached);
        rethrow;
      }
    }
    return _mergePending(await _getFromCache());
  }

  /// Страница склада: поиск идёт на сервере (OEM, аналоги, штрихкод).
  /// Кэш не перезаписывается — его держит полная синхронизация.
  /// Офлайн — тот же поиск по кэшу.
  Future<ItemsPage> searchItems({
    String query = '',
    Map<String, dynamic>? filters,
    int offset = 0,
    int limit = 50,
  }) async {
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get(
          '/api/items',
          queryParameters: {
            ...?filters,
            if (query.trim().isNotEmpty) 'search': query.trim(),
            'limit': limit,
            'offset': offset,
          },
        );
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List<dynamic>)
            .map((j) => ItemModel.fromJson(j as Map<String, dynamic>))
            .toList();
        return ItemsPage(
          items: offset == 0 ? await _mergePending(items) : items,
          total: (data['total'] as num?)?.toInt() ?? items.length,
        );
      } catch (e) {
        debugPrint('[ItemsRepo] Search failed, falling back to cache: $e');
        final cached = await _searchCache(query, offset, limit);
        if (cached.items.isNotEmpty || offset > 0) return cached;
        rethrow;
      }
    }
    return _searchCache(query, offset, limit);
  }

  Future<ItemsPage> _searchCache(String query, int offset, int limit) async {
    final matches = (await _mergePending(
      await _getFromCache(),
    )).where((item) => item.matchesQuery(query)).toList();
    return ItemsPage(
      items: matches.skip(offset).take(limit).toList(),
      total: matches.length,
    );
  }

  Future<List<ItemModel>> _mergePending(List<ItemModel> items) async {
    final merged = List<ItemModel>.of(items);
    for (final json in await OfflineQueue().snapshots('item')) {
      try {
        final pending = ItemModel.fromJson(json);
        final index = merged.indexWhere((item) => item.id == pending.id);
        if (index >= 0) {
          merged[index] = pending;
        } else {
          merged.insert(0, pending);
        }
      } catch (e) {
        debugPrint('[ItemsRepo] Skip pending item: $e');
      }
    }
    return merged;
  }

  Future<ItemModel?> getItem(int id) async {
    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.get('/api/items/$id');
        return ItemModel.fromJson(response.data);
      } catch (e) {
        debugPrint('[ItemsRepo] API getItem failed, checking cache: $e');
        return _getItemFromCache(id);
      }
    }
    return _getItemFromCache(id);
  }

  /// Код с этикетки или сканера: QR с id, штрихкод, артикул, внутренний код или OEM.
  Future<ItemModel?> findByCode(String code) async {
    final parsed = LabelQrPayload.parse(code);
    if (_connectivity.isOnline) {
      try {
        if (parsed.id != null) {
          final byId = await getItem(parsed.id!);
          if (byId != null) {
            return byId;
          }
        }
        for (final candidate in {
          if (parsed.sku != null && parsed.sku!.isNotEmpty) parsed.sku!,
          parsed.raw,
        }) {
          final response = await _api.dio.get(
            '/api/items',
            queryParameters: {'code': candidate},
          );
          final List<dynamic> data = response.data;
          if (data.isNotEmpty) {
            return ItemModel.fromJson(data[0]);
          }
        }
        return null;
      } catch (_) {
        return _findByCodeFromCache(parsed);
      }
    }
    return _findByCodeFromCache(parsed);
  }

  bool get isOffline => !_connectivity.isOnline;

  // --- Private cache helpers ---

  Future<List<ItemModel>> _getFromCache() async {
    final rows = await _db.getAllItems();
    return rows.map(_mapDriftToModel).toList();
  }

  Future<ItemModel?> _getItemFromCache(int id) async {
    final row = await _db.getItemById(id);
    return row != null ? _mapDriftToModel(row) : null;
  }

  Future<ItemModel?> _findByCodeFromCache(LabelQrPayload parsed) async {
    if (parsed.id != null) {
      final row = await _db.getItemById(parsed.id!);
      if (row != null) {
        return _mapDriftToModel(row);
      }
    }
    final rows = await _db.getAllItems();
    if (parsed.sku != null && parsed.sku!.isNotEmpty) {
      final match = rows.where(
        (r) => r.sku?.toLowerCase() == parsed.sku!.toLowerCase(),
      );
      if (match.isNotEmpty) {
        return _mapDriftToModel(match.first);
      }
    }
    if (parsed.raw.isNotEmpty) {
      final want = parsed.raw.toLowerCase();
      final match = rows.where((r) => r.sku?.toLowerCase() == want);
      if (match.isNotEmpty) {
        return _mapDriftToModel(match.first);
      }
    }
    return null;
  }

  Future<void> _cacheItems(List<ItemModel> items) async {
    try {
      await _db.batch((batch) async {
        batch.deleteAll(_db.items);
        for (final item in items) {
          batch.insert(
            _db.items,
            ItemsCompanion.insert(
              id: Value(item.id ?? 0),
              name: item.name,
              category: item.category ?? '',
              sku: Value(item.sku),
              price: item.price,
              quantity: Value(item.quantity),
              condition: item.condition,
              description: Value(item.description),
              imageUrl: Value(item.imageUrl),
              synced: const Value(true),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[ItemsRepo] Cache write failed: $e');
    }
  }

  Future<void> enqueueOfflineCreate(Map<String, dynamic> data) async {
    await _db.insertSyncItem(
      SyncQueueCompanion.insert(
        syncTableName: 'items',
        operation: 'create',
        recordId: 0,
        data: jsonEncode(data),
      ),
    );
  }

  ItemModel _mapDriftToModel(Item row) {
    return ItemModel(
      id: row.id,
      name: row.name,
      category: row.category,
      sku: row.sku,
      price: row.price,
      quantity: row.quantity,
      condition: row.condition,
      description: row.description,
      imageUrl: row.imageUrl,
      synced: row.synced,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
