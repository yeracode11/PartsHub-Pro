import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/models/incoming_item_model.dart';
import 'package:autohub_b2b/services/offline_queue.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';

class IncomingApiService {
  final ApiClient _apiClient;

  IncomingApiService(this._apiClient);

  /// Получить список приходных накладных
  Future<List<IncomingDocModel>> getDocuments({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (!OfflineQueue().isOnline) return _documentsFromCache(status);
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String().split('T')[0];
      }
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo.toIso8601String().split('T')[0];
      }

      final response = await _apiClient.dio.get(
        '/api/incoming',
        queryParameters: queryParams,
      );

      final List<dynamic> data = response.data;
      final raw = data
          .whereType<Map>()
          .map((json) => Map<String, dynamic>.from(json))
          .toList();
      await OfflineQueue().writeList('incoming', raw);
      final docs = raw.map(IncomingDocModel.fromJson).toList();
      final locals = await _localDocuments();
      return [...docs, ...locals.where((doc) => _matchesStatus(doc, status))];
    } catch (e) {
      if (!isNetworkError(e) && OfflineQueue().isOnline) rethrow;
      return _documentsFromCache(status);
    }
  }

  Future<List<IncomingDocModel>> _documentsFromCache(String? status) async {
    final cached = await OfflineQueue().readList('incoming') ?? [];
    final docs = <IncomingDocModel>[];
    for (final json in cached) {
      try {
        docs.add(IncomingDocModel.fromJson(json));
      } catch (_) {}
    }
    docs.addAll(await _localDocuments());
    return docs.where((doc) => _matchesStatus(doc, status)).toList();
  }

  /// Получить одну накладную
  Future<IncomingDocModel> getDocument(String id) async {
    final resolved = await OfflineQueue().canonical(id);
    if (!OfflineQueue().isOnline || OfflineQueue.isTemporaryId(resolved)) {
      final local = await OfflineQueue().incomingLocal(id) ??
          await OfflineQueue().incomingLocal(resolved);
      if (local != null) return IncomingDocModel.fromJson(local);
      final cached = await OfflineQueue().readList('incoming') ?? [];
      for (final json in cached) {
        if (json['id']?.toString() == resolved || json['id']?.toString() == id) {
          return IncomingDocModel.fromJson(json);
        }
      }
      throw Exception('Накладная не найдена на устройстве');
    }
    try {
      final response = await _apiClient.dio.get('/api/incoming/$resolved');
      return IncomingDocModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      final local = await OfflineQueue().incomingLocal(id);
      if (local != null) return IncomingDocModel.fromJson(local);
      final cached = await OfflineQueue().readList('incoming') ?? [];
      for (final json in cached) {
        if (json['id']?.toString() == resolved || json['id']?.toString() == id) {
          return IncomingDocModel.fromJson(json);
        }
      }
      rethrow;
    }
  }

  /// Создать приходную накладную
  Future<IncomingDocModel> createDocument(Map<String, dynamic> data) async {
    final localId = OfflineQueue.newLocalStringId();
    final now = DateTime.now().toIso8601String();
    final snapshot = <String, dynamic>{
      ...data,
      'id': localId,
      'docNumber': 'Офлайн',
      'status': 'draft',
      'createdById': 'local',
      'totalAmount': 0,
      'items': <Map<String, dynamic>>[],
      'createdAt': now,
      'updatedAt': now,
    };
    final result = await OfflineQueue().send(
      method: 'POST',
      path: '/api/incoming',
      body: data,
      entity: 'incoming',
      snapshot: snapshot,
      localId: localId,
    );
    final json = _asMap(result.data) ?? snapshot;
    if (result.queued) await _storeDoc(json);
    return IncomingDocModel.fromJson(json);
  }

  /// Обновить накладную
  Future<IncomingDocModel> updateDocument(
    String id,
    Map<String, dynamic> data,
  ) async {
    final current = await _documentJson(id);
    final now = DateTime.now().toIso8601String();
    final snapshot = _completeDoc({
      ...?current,
      ...data,
      'id': current?['id'] ?? id,
      'updatedAt': now,
    }, now);
    final result = await OfflineQueue().send(
      method: 'PUT',
      path: '/api/incoming/$id',
      body: data,
      entity: 'incoming',
      snapshot: snapshot,
      localId: id,
    );
    final json = _asMap(result.data) ?? snapshot;
    if (result.queued) await _storeDoc(json);
    return IncomingDocModel.fromJson(json);
  }

  /// Добавить позицию в накладную
  Future<IncomingItemModel> addItem(
    String docId,
    Map<String, dynamic> itemData,
  ) async {
    final now = DateTime.now().toIso8601String();
    final itemId = OfflineQueue.newLocalStringId();
    final itemSnapshot = <String, dynamic>{
      ...itemData,
      'id': itemId,
      'docId': docId,
      'createdAt': now,
      'updatedAt': now,
    };
    final result = await OfflineQueue().send(
      method: 'POST',
      path: '/api/incoming/$docId/items',
      body: itemData,
      entity: 'incomingItem',
      snapshot: itemSnapshot,
      localId: itemId,
    );
    final json = _asMap(result.data) ?? itemSnapshot;
    if (result.queued) {
      final doc = await _documentJson(docId);
      if (doc != null) {
        final items = (doc['items'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        items.add(itemSnapshot);
        doc['items'] = items;
        final price = itemData['purchasePrice'];
        final qty = itemData['quantity'];
        final line = (price is num ? price.toDouble() : double.tryParse('$price') ?? 0) *
            (qty is num ? qty.toDouble() : double.tryParse('$qty') ?? 0);
        final total = doc['totalAmount'];
        doc['totalAmount'] =
            (total is num ? total.toDouble() : double.tryParse('$total') ?? 0) + line;
        await _storeDoc(doc);
      }
    }
    return IncomingItemModel.fromJson(json);
  }

  /// Удалить позицию
  Future<void> removeItem(String itemId) async {
    final result = await OfflineQueue().send(
      method: 'DELETE',
      path: '/api/incoming/items/$itemId',
      entity: 'incomingItem',
      snapshot: {'id': itemId, 'remove': true},
      localId: itemId,
    );
    if (!result.queued) return;
    final docs = [
      ...await OfflineQueue().incomingLocals(),
      ...?await OfflineQueue().readList('incoming'),
    ];
    for (final doc in docs) {
      final items = doc['items'];
      if (items is! List) continue;
      final next = items
          .whereType<Map>()
          .where((item) => item['id']?.toString() != itemId)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (next.length == items.length) continue;
      doc['items'] = next;
      await _storeDoc(doc);
    }
  }

  /// Провести накладную
  Future<IncomingDocModel> processDocument(String id) async {
    final current = await _documentJson(id);
    final now = DateTime.now().toIso8601String();
    final snapshot = _completeDoc({
      ...?current,
      'id': current?['id'] ?? id,
      'status': 'done',
      'updatedAt': now,
    }, now);
    final result = await OfflineQueue().send(
      method: 'POST',
      path: '/api/incoming/$id/process',
      entity: 'incoming',
      snapshot: snapshot,
      localId: id,
    );
    final json = _asMap(result.data) ?? snapshot;
    if (result.queued) await _storeDoc(json);
    return IncomingDocModel.fromJson(json);
  }

  /// Удалить накладную
  Future<void> deleteDocument(String id) async {
    await OfflineQueue().send(
      method: 'DELETE',
      path: '/api/incoming/$id',
      entity: 'incoming',
      snapshot: {'id': id, 'remove': true},
      localId: id,
    );
  }

  Future<List<IncomingDocModel>> _localDocuments() async {
    final docs = <IncomingDocModel>[];
    for (final json in await OfflineQueue().incomingLocals()) {
      try {
        docs.add(IncomingDocModel.fromJson(json));
      } catch (_) {}
    }
    return docs;
  }

  Future<void> _storeDoc(Map<String, dynamic> doc) async {
    final id = doc['id']?.toString() ?? '';
    if (OfflineQueue.isTemporaryId(id)) {
      await OfflineQueue().saveIncomingLocal(doc);
      return;
    }
    final cached = await OfflineQueue().readList('incoming') ?? [];
    final index = cached.indexWhere((item) => item['id']?.toString() == id);
    if (index >= 0) {
      cached[index] = doc;
    } else {
      cached.insert(0, doc);
    }
    await OfflineQueue().writeList('incoming', cached);
  }

  Future<Map<String, dynamic>?> _documentJson(String id) async {
    final local = await OfflineQueue().incomingLocal(id);
    if (local != null) return local;
    final cached = await OfflineQueue().readList('incoming') ?? [];
    for (final json in cached) {
      if (json['id']?.toString() == id) return Map<String, dynamic>.from(json);
    }
    return null;
  }

  Map<String, dynamic> _completeDoc(Map<String, dynamic> doc, String now) {
    return {
      'docNumber': 'Офлайн',
      'date': now,
      'type': 'new_parts',
      'status': 'draft',
      'createdById': 'local',
      'totalAmount': 0,
      'items': <Map<String, dynamic>>[],
      'createdAt': now,
      ...doc,
    };
  }

  bool _matchesStatus(IncomingDocModel doc, String? status) {
    if (status == null || status.isEmpty) return true;
    return doc.status.name == status;
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

