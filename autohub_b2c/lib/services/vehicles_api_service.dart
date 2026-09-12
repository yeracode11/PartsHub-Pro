import '../models/vehicle_model.dart';
import 'api_client.dart';

class VehiclesApiService {
  final ApiClient _apiClient;

  VehiclesApiService(this._apiClient);

  Future<List<Vehicle>> getUserVehicles() async {
    final response = await _apiClient.get('/vehicles');
    final data = response.data;
    if (data is List) {
      return data
          .map((json) => Vehicle.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  Future<List<Vehicle>> getCustomerVehicles(int customerId) async {
    final response = await _apiClient.get('/vehicles/customer/$customerId');
    final data = response.data;
    if (data is List) {
      return data
          .map((json) => Vehicle.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  Future<Vehicle> getVehicle(int id) async {
    final response = await _apiClient.get('/vehicles/$id');
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Vehicle> createVehicle(Map<String, dynamic> vehicleData) async {
    final response = await _apiClient.post('/vehicles', data: vehicleData);
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Vehicle> updateVehicle(int id, Map<String, dynamic> vehicleData) async {
    final response = await _apiClient.put('/vehicles/$id', data: vehicleData);
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteVehicle(int id) async {
    await _apiClient.delete('/vehicles/$id');
  }

  Future<Vehicle> updateMileage(int id, int newMileage) async {
    final response = await _apiClient.put(
      '/vehicles/$id/mileage',
      data: {'mileage': newMileage},
    );
    return Vehicle.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
