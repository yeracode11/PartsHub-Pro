import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class SyncService {
  final AppDatabase database;
  final Dio dio;
  final String baseUrl;
  
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService({
    required this.database,
    required this.baseUrl,
    Dio? dio,
  }) : dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  /// Запускает периодическую синхронизацию
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) => syncAll());
  }

  /// Останавливает периодическую синхронизацию
  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  /// Синхронизирует все несинхронизированные данные
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        message: 'Синхронизация уже выполняется',
      );
    }

    _isSyncing = true;
    int successCount = 0;
    int failureCount = 0;
    String? errorMessage;

    try {
      final unsyncedItems = await database.getUnsyncedItems();

      for (final syncItem in unsyncedItems) {
        try {
          final result = await _syncItem(syncItem);
          if (result) {
            await database.markSynced(syncItem.id);
            successCount++;
          } else {
            failureCount++;
          }
        } catch (e) {
          failureCount++;
          errorMessage = e.toString();
        }
      }

      return SyncResult(
        success: failureCount == 0,
        message: 'Синхронизировано: $successCount, Ошибок: $failureCount',
        syncedCount: successCount,
        failedCount: failureCount,
        errorMessage: errorMessage,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        message: 'Ошибка синхронизации',
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Синхронизирует отдельный элемент
  Future<bool> _syncItem(SyncQueueData syncItem) async {
    try {
      final data = jsonDecode(syncItem.data);
      final endpoint = _getEndpoint(syncItem.syncTableName);

      switch (syncItem.operation) {
        case 'create':
          await dio.post(endpoint, data: data);
          break;
        case 'update':
          await dio.put('$endpoint/${syncItem.recordId}', data: data);
          break;
        case 'delete':
          await dio.delete('$endpoint/${syncItem.recordId}');
          break;
        default:
          throw Exception('Unknown operation: ${syncItem.operation}');
      }

      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 409) {
        // Conflict или не найдено - считаем синхронизированным
        return true;
      }
      rethrow;
    }
  }

  /// Добавляет запись в очередь синхронизации
  Future<void> addToSyncQueue({
    required String tableName,
    required String operation,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    final companion = SyncQueueCompanion(
      syncTableName: drift.Value(tableName),
      operation: drift.Value(operation),
      recordId: drift.Value(recordId),
      data: drift.Value(jsonEncode(data)),
      synced: const drift.Value(false),
    );

    await database.insertSyncItem(companion);
  }

  /// Получает URL endpoint для таблицы
  String _getEndpoint(String tableName) {
    switch (tableName) {
      case 'items':
        return '/api/items';
      case 'orders':
        return '/api/orders';
      case 'customers':
        return '/api/customers';
      case 'movements':
        return '/api/movements';
      default:
        return '/api/$tableName';
    }
  }

  /// Проверяет доступность сервера
  Future<bool> isServerAvailable() async {
    try {
      final response = await dio.get('/api/health').timeout(
            const Duration(seconds: 5),
          );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    stopPeriodicSync();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final String? errorMessage;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'SyncResult(success: $success, message: $message, '
        'synced: $syncedCount, failed: $failedCount)';
  }
}

