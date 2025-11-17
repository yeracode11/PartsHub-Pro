import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/incoming_doc_model.dart';
import 'package:autohub_b2b/models/incoming_item_model.dart';

class IncomingApiService {
  final ApiClient _apiClient;

  IncomingApiService(this._apiClient);

  /// Получить список приходных накладных
  Future<List<IncomingDocModel>> getDocuments({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
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
      return data
          .map((json) => IncomingDocModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Ошибка получения накладных: $e');
    }
  }

  /// Получить одну накладную
  Future<IncomingDocModel> getDocument(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/incoming/$id');
      return IncomingDocModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Ошибка получения накладной: $e');
    }
  }

  /// Создать приходную накладную
  Future<IncomingDocModel> createDocument(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/api/incoming', data: data);
      return IncomingDocModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Ошибка создания накладной: $e');
    }
  }

  /// Обновить накладную
  Future<IncomingDocModel> updateDocument(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put('/api/incoming/$id', data: data);
      return IncomingDocModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Ошибка обновления накладной: $e');
    }
  }

  /// Добавить позицию в накладную
  Future<IncomingItemModel> addItem(
    String docId,
    Map<String, dynamic> itemData,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/incoming/$docId/items',
        data: itemData,
      );
      return IncomingItemModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Ошибка добавления позиции: $e');
    }
  }

  /// Удалить позицию
  Future<void> removeItem(String itemId) async {
    try {
      await _apiClient.dio.delete('/api/incoming/items/$itemId');
    } catch (e) {
      throw Exception('Ошибка удаления позиции: $e');
    }
  }

  /// Провести накладную
  Future<IncomingDocModel> processDocument(String id) async {
    try {
      final response = await _apiClient.dio.post('/api/incoming/$id/process');
      return IncomingDocModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Ошибка проведения накладной: $e');
    }
  }

  /// Удалить накладную
  Future<void> deleteDocument(String id) async {
    try {
      await _apiClient.dio.delete('/api/incoming/$id');
    } catch (e) {
      throw Exception('Ошибка удаления накладной: $e');
    }
  }
}

