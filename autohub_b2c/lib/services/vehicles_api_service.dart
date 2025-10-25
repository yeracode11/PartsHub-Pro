import 'package:dio/dio.dart';
import '../models/vehicle_model.dart';
import 'api_client.dart';

class VehiclesApiService {
  final ApiClient _apiClient;

  VehiclesApiService(this._apiClient);

  // Получить все автомобили пользователя
  Future<List<Vehicle>> getUserVehicles() async {
    try {
      final response = await _apiClient.get('/vehicles');
      final data = response.data as List<dynamic>;
      return data.map((json) => Vehicle.fromJson(json)).toList();
    } catch (e) {
      // Если API недоступен, используем моковые данные
      print('API недоступен, используем моковые данные: $e');
      return _getMockVehicles();
    }
  }

  // Получить автомобиль по ID
  Future<Vehicle> getVehicle(int id) async {
    try {
      final response = await _apiClient.get('/vehicles/$id');
      return Vehicle.fromJson(response.data);
    } catch (e) {
      // Fallback to mock data
      final vehicles = _getMockVehicles();
      return vehicles.firstWhere((v) => v.id == id);
    }
  }

  // Создать новый автомобиль
  Future<Vehicle> createVehicle(Map<String, dynamic> vehicleData) async {
    try {
      final response = await _apiClient.post('/vehicles', data: vehicleData);
      return Vehicle.fromJson(response.data);
    } catch (e) {
      throw Exception('Не удалось создать автомобиль: $e');
    }
  }

  // Обновить автомобиль
  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> vehicleData) async {
    try {
      final response = await _apiClient.put('/vehicles/$id', data: vehicleData);
      return Vehicle.fromJson(response.data);
    } catch (e) {
      throw Exception('Не удалось обновить автомобиль: $e');
    }
  }

  // Удалить автомобиль
  Future<void> deleteVehicle(int id) async {
    try {
      await _apiClient.delete('/vehicles/$id');
    } catch (e) {
      throw Exception('Не удалось удалить автомобиль: $e');
    }
  }

  // Обновить пробег автомобиля
  Future<Vehicle> updateMileage(int id, int newMileage) async {
    try {
      final response = await _apiClient.put(
        '/vehicles/$id/mileage',
        data: {'currentMileage': newMileage},
      );
      return Vehicle.fromJson(response.data);
    } catch (e) {
      throw Exception('Не удалось обновить пробег: $e');
    }
  }

  // Mock data для fallback
  List<Vehicle> _getMockVehicles() {
    final now = DateTime.now();
    return [
      Vehicle(
        id: 1,
        brand: 'Toyota',
        model: 'Camry',
        year: 2018,
        color: 'Белый',
        plateNumber: '123ABC01',
        vin: '1HGBH41JXMN109186',
        fuelType: FuelType.petrol,
        transmission: TransmissionType.automatic,
        engineVolume: '2.5',
        enginePower: 181,
        currentMileage: 85000,
        lastServiceMileage: 80000,
        lastServiceDate: now.subtract(const Duration(days: 90)),
        nextServiceMileage: 95000,
        nextServiceDate: now.add(const Duration(days: 90)),
        notes: 'Хорошее состояние, регулярное обслуживание',
        createdAt: now.subtract(const Duration(days: 365)),
        updatedAt: now,
      ),
      Vehicle(
        id: 2,
        brand: 'BMW',
        model: 'X5',
        year: 2016,
        color: 'Черный',
        plateNumber: '456DEF02',
        vin: 'WBAKS4107MC123456',
        fuelType: FuelType.diesel,
        transmission: TransmissionType.automatic,
        engineVolume: '3.0',
        enginePower: 258,
        currentMileage: 120000,
        lastServiceMileage: 115000,
        lastServiceDate: now.subtract(const Duration(days: 60)),
        nextServiceMileage: 130000,
        nextServiceDate: now.add(const Duration(days: 30)),
        notes: 'Требуется замена шин',
        createdAt: now.subtract(const Duration(days: 200)),
        updatedAt: now.subtract(const Duration(days: 30)),
      ),
    ];
  }
}
