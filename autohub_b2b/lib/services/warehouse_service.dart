import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/warehouse_model.dart';
import '../core/config.dart';
import 'auth_service.dart';

class WarehouseService {
  final String baseUrl = Config.apiUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Получить список всех складов
  Future<List<Warehouse>> getWarehouses() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/warehouses'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Warehouse.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load warehouses: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getWarehouses: $e');
      throw Exception('Failed to load warehouses: $e');
    }
  }

  // Получить склад по ID
  Future<Warehouse> getWarehouse(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/warehouses/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Warehouse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load warehouse: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getWarehouse: $e');
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
      final headers = await _getHeaders();
      final body = json.encode({
        'name': name,
        'address': address,
        'phone': phone,
        'contactPerson': contactPerson,
        'isActive': isActive,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/warehouses'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return Warehouse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create warehouse: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in createWarehouse: $e');
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
      final headers = await _getHeaders();
      final body = json.encode({
        if (name != null) 'name': name,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (contactPerson != null) 'contactPerson': contactPerson,
        if (isActive != null) 'isActive': isActive,
      });

      final response = await http.patch(
        Uri.parse('$baseUrl/warehouses/$id'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return Warehouse.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update warehouse: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateWarehouse: $e');
      throw Exception('Failed to update warehouse: $e');
    }
  }

  // Удалить склад
  Future<void> deleteWarehouse(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/warehouses/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete warehouse: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in deleteWarehouse: $e');
      throw Exception('Failed to delete warehouse: $e');
    }
  }

  // Получить количество товаров на складе
  Future<int> getItemsCount(String warehouseId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/warehouses/$warehouseId/items-count'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      } else {
        throw Exception('Failed to load items count: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getItemsCount: $e');
      return 0;
    }
  }

  // --- Методы для перемещений товаров ---

  // Получить список всех перемещений
  Future<List<WarehouseTransfer>> getTransfers() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/warehouse-transfers'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => WarehouseTransfer.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load transfers: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in getTransfers: $e');
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
      final headers = await _getHeaders();
      final body = json.encode({
        'fromWarehouseId': fromWarehouseId,
        'toWarehouseId': toWarehouseId,
        'itemId': itemId,
        'quantity': quantity,
        'notes': notes,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/warehouse-transfers'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        return WarehouseTransfer.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create transfer: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in createTransfer: $e');
      throw Exception('Failed to create transfer: $e');
    }
  }

  // Обновить статус перемещения
  Future<WarehouseTransfer> updateTransferStatus(
    String id,
    TransferStatus status,
  ) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'status': status.toString(),
      });

      final response = await http.patch(
        Uri.parse('$baseUrl/warehouse-transfers/$id/status'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        return WarehouseTransfer.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update transfer status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in updateTransferStatus: $e');
      throw Exception('Failed to update transfer status: $e');
    }
  }

  // Удалить перемещение
  Future<void> deleteTransfer(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/warehouse-transfers/$id'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete transfer: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in deleteTransfer: $e');
      throw Exception('Failed to delete transfer: $e');
    }
  }
}

