import '../models/warehouse_model.dart';
import 'api/api_client.dart';

class WarehouseService {
  final ApiClient _apiClient = ApiClient();

  // Получить список всех складов
  Future<List<Warehouse>> getWarehouses() async {
    try {
      final response = await _apiClient.dio.get('/api/warehouses');
      final List<dynamic> data = response.data;
      return data.map((json) => Warehouse.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load warehouses: $e');
    }
  }

  // Получить склад по ID
  Future<Warehouse> getWarehouse(String id) async {
    try {
      final response = await _apiClient.dio.get('/api/warehouses/$id');
      return Warehouse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load warehouse: $e');
    }
  }

  // Создать новый склад
  Future<Warehouse> createWarehouse({
    required String name,
    String? address,
    String? phone,
    String? contactPerson,
    bool isActive = true,
  }) async {
    try {
      final response = await _apiClient.dio.post('/api/warehouses', data: {
        'name': name,
        'address': address,
        'phone': phone,
        'contactPerson': contactPerson,
        'isActive': isActive,
      });
      return Warehouse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create warehouse: $e');
    }
  }

  // Обновить склад
  Future<Warehouse> updateWarehouse(
    String id, {
    String? name,
    String? address,
    String? phone,
    String? contactPerson,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.dio.patch('/api/warehouses/$id', data: {
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (isActive != null) 'isActive': isActive,
      });
      return Warehouse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update warehouse: $e');
    }
  }

  // Удалить склад
  Future<void> deleteWarehouse(String id) async {
    try {
      await _apiClient.dio.delete('/api/warehouses/$id');
    } catch (e) {
      throw Exception('Failed to delete warehouse: $e');
    }
  }

  // Получить количество товаров на складе
  Future<int> getItemsCount(String warehouseId) async {
    try {
      final response = await _apiClient.dio.get('/api/warehouses/$warehouseId/items-count');
      return response.data['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // --- Методы для перемещений товаров ---

  // Получить список всех перемещений
  Future<List<WarehouseTransfer>> getTransfers() async {
    try {
      final response = await _apiClient.dio.get('/api/warehouse-transfers');
      final List<dynamic> data = response.data;
      return data.map((json) => WarehouseTransfer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load transfers: $e');
    }
  }

  // Создать новое перемещение
  Future<WarehouseTransfer> createTransfer({
    required String fromWarehouseId,
    required String toWarehouseId,
    required int itemId,
    required int quantity,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.dio.post('/api/warehouse-transfers', data: {
        'fromWarehouseId': fromWarehouseId,
        'toWarehouseId': toWarehouseId,
        'itemId': itemId,
        'quantity': quantity,
        'notes': notes,
      });
      return WarehouseTransfer.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create transfer: $e');
    }
  }

  // Обновить статус перемещения
  Future<WarehouseTransfer> updateTransferStatus(
    String id,
    TransferStatus status,
  ) async {
    try {
      final response = await _apiClient.dio.patch('/api/warehouse-transfers/$id/status', data: {
        'status': status.toString(),
      });
      return WarehouseTransfer.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update transfer status: $e');
    }
  }

  // Удалить перемещение
  Future<void> deleteTransfer(String id) async {
    try {
      await _apiClient.dio.delete('/api/warehouse-transfers/$id');
    } catch (e) {
      throw Exception('Failed to delete transfer: $e');
    }
  }
}

