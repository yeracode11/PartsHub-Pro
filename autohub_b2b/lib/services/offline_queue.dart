import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/connectivity_service.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:autohub_b2b/services/service_locator.dart';
import 'package:autohub_b2b/widgets/offline_placeholder.dart';

const offlineSavedMessage =
    'Сохранено на устройстве. Отправится, когда появится сеть.';

class OfflineSendResult {
  const OfflineSendResult({required this.queued, required this.data});

  final bool queued;
  final dynamic data;
}

/// Очередь записей, которые не удалось отправить, и локальные копии списков.
class OfflineQueue {
  static final OfflineQueue _instance = OfflineQueue._();
  factory OfflineQueue() => _instance;
  OfflineQueue._();

  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  Future<void> _cacheLock = Future.value();

  AppDatabase get _db => ServiceLocator().database;

  bool get isOnline => _connectivity.isOnline;

  static int newLocalIntId() => -DateTime.now().microsecondsSinceEpoch;

  static String newLocalStringId() =>
      'local-${DateTime.now().microsecondsSinceEpoch}';

  static bool isTemporaryId(String id) =>
      id.startsWith('-') || id.startsWith('local-');

  /// Отправляет запрос. Без сети кладёт его в очередь и возвращает [snapshot].
  Future<OfflineSendResult> send({
    required String method,
    required String path,
    Object? body,
    required String entity,
    required Map<String, dynamic> snapshot,
    String? localId,
  }) async {
    final resolvedPath = await _applyAliasesToPath(path);
    final resolvedBody = await _applyAliases(body);

    if (_connectivity.isOnline) {
      try {
        final response = await _api.dio.request(
          resolvedPath,
          data: resolvedBody,
          options: Options(method: method),
        );
        return OfflineSendResult(queued: false, data: response.data);
      } catch (e) {
        if (!isNetworkError(e)) rethrow;
        _connectivity.reportOffline();
      }
    }

    final id = localId ?? snapshot['id']?.toString() ?? newLocalStringId();
    await _db.insertSyncItem(
      SyncQueueCompanion.insert(
        syncTableName: entity,
        operation: 'http',
        recordId: 0,
        data: jsonEncode({
          'method': method,
          'path': resolvedPath,
          'body': resolvedBody,
          'entity': entity,
          'localId': id,
          'snapshot': snapshot,
        }),
      ),
    );
    return OfflineSendResult(queued: true, data: snapshot);
  }

  Future<List<Map<String, dynamic>>> snapshots(String entity) async {
    final rows = await _db.getUnsyncedItems();
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row.operation != 'http' || row.syncTableName != entity) continue;
      final decoded = jsonDecode(row.data);
      if (decoded is! Map || decoded['snapshot'] is! Map) continue;
      result.add(Map<String, dynamic>.from(decoded['snapshot'] as Map));
    }
    return result;
  }

  /// Подменяет временные id на серверные в ещё не отправленных запросах.
  Future<Map<String, dynamic>> prepareEnvelope(Map<String, dynamic> envelope) async {
    final aliases = await _aliases();
    if (aliases.isEmpty) return envelope;
    final rewritten = _rewrite(envelope, aliases);
    if (rewritten is Map<String, dynamic>) return rewritten;
    return Map<String, dynamic>.from(rewritten as Map);
  }

  Future<void> rememberAlias(String? localId, dynamic response) async {
    if (localId == null || !isTemporaryId(localId)) return;
    if (response is! Map || response['id'] == null) return;
    final serverId = response['id'].toString();
    if (serverId.isEmpty || serverId == localId) return;
    await _updateCache((cache) {
      final aliases = Map<String, dynamic>.from(cache['aliases'] as Map? ?? {});
      aliases[localId] = serverId;
      cache['aliases'] = aliases;
      final docs = Map<String, dynamic>.from(cache['incomingLocal'] as Map? ?? {});
      docs.remove(localId);
      cache['incomingLocal'] = docs;
    });
  }

  Future<String> canonical(String id) async {
    final aliases = await _aliases();
    return aliases[id] ?? id;
  }

  Future<void> saveIncomingLocal(Map<String, dynamic> doc) async {
    final id = doc['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _updateCache((cache) {
      final docs = Map<String, dynamic>.from(cache['incomingLocal'] as Map? ?? {});
      docs[id] = doc;
      cache['incomingLocal'] = docs;
    });
  }

  Future<Map<String, dynamic>?> incomingLocal(String id) async {
    final cache = await _readCache();
    final docs = cache['incomingLocal'];
    if (docs is! Map || docs[id] is! Map) return null;
    return Map<String, dynamic>.from(docs[id] as Map);
  }

  Future<List<Map<String, dynamic>>> incomingLocals() async {
    final cache = await _readCache();
    final docs = cache['incomingLocal'];
    if (docs is! Map) return [];
    return docs.values
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> rows) {
    return _updateCache((cache) {
      final lists = Map<String, dynamic>.from(cache['lists'] as Map? ?? {});
      lists[key] = rows;
      cache['lists'] = lists;
    });
  }

  /// null — списка ещё не было. Пустой список — он уже загружался.
  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final cache = await _readCache();
    final lists = cache['lists'];
    if (lists is! Map || !lists.containsKey(key)) return null;
    final rows = lists[key];
    if (rows is! List) return [];
    return rows
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) {
    return _updateCache((cache) {
      final maps = Map<String, dynamic>.from(cache['maps'] as Map? ?? {});
      maps[key] = value;
      cache['maps'] = maps;
    });
  }

  Future<Map<String, dynamic>?> readMap(String key) async {
    final cache = await _readCache();
    final maps = cache['maps'];
    if (maps is! Map || maps[key] is! Map) return null;
    return Map<String, dynamic>.from(maps[key] as Map);
  }

  Future<String> _applyAliasesToPath(String path) async {
    final rewritten = await _applyAliases(path);
    return rewritten is String ? rewritten : path;
  }

  Future<dynamic> _applyAliases(dynamic node) async {
    final aliases = await _aliases();
    if (aliases.isEmpty) return node;
    return _rewrite(node, aliases);
  }

  Future<Map<String, String>> _aliases() async {
    final cache = await _readCache();
    final raw = cache['aliases'];
    if (raw is! Map) return {};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  dynamic _rewrite(dynamic node, Map<String, String> aliases) {
    if (node is Map) {
      return node.map((key, value) => MapEntry(key, _rewrite(value, aliases)));
    }
    if (node is List) {
      return node.map((value) => _rewrite(value, aliases)).toList();
    }
    if (node is int) {
      final server = aliases[node.toString()];
      if (server == null) return node;
      return int.tryParse(server) ?? server;
    }
    if (node is String) {
      if (aliases.containsKey(node)) return aliases[node];
      var text = node;
      for (final entry in aliases.entries) {
        text = text.replaceAll('/${entry.key}/', '/${entry.value}/');
        if (text.endsWith('/${entry.key}')) {
          text = '${text.substring(0, text.length - entry.key.length)}${entry.value}';
        }
      }
      return text;
    }
    return node;
  }

  Future<File> _cacheFile() async {
    final folder = await getApplicationDocumentsDirectory();
    return File(p.join(folder.path, 'offline_cache.json'));
  }

  Future<Map<String, dynamic>> _readCache() {
    return _synchronized(() async {
      try {
        final file = await _cacheFile();
        if (!await file.exists()) return <String, dynamic>{};
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('[OfflineQueue] cache read failed: $e');
      }
      return <String, dynamic>{};
    });
  }

  Future<void> _updateCache(void Function(Map<String, dynamic> cache) change) {
    return _synchronized(() async {
      final file = await _cacheFile();
      Map<String, dynamic> cache = {};
      try {
        if (await file.exists()) {
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is Map) cache = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint('[OfflineQueue] cache parse failed: $e');
      }
      change(cache);
      await file.writeAsString(jsonEncode(cache));
    });
  }

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final result = _cacheLock.then((_) => action());
    _cacheLock = result.then((_) {}, onError: (_) {});
    return result;
  }
}
