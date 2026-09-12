import '../models/service_model.dart';
import 'api_client.dart';

class ServicesApiService {
  final ApiClient _apiClient;

  ServicesApiService(this._apiClient);

  Future<List<AutoService>> getServices({
    String? search,
    String? category,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    final queryParams = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (latitude != null && longitude != null) {
      queryParams['latitude'] = latitude;
      queryParams['longitude'] = longitude;
      queryParams['radius'] = radius ?? 10.0;
    }

    final response = await _apiClient.get(
      '/b2c/services',
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => AutoService.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<AutoService> getServiceById(String serviceId) async {
    final response = await _apiClient.get('/services/$serviceId');
    return AutoService.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<List<String>> getAvailableTimeSlots(
    String serviceId,
    DateTime date,
  ) async {
    final response = await _apiClient.get(
      '/services/$serviceId/availability',
      queryParameters: {'date': date.toIso8601String().split('T')[0]},
    );
    return List<String>.from(response.data['timeSlots'] ?? []);
  }

  Future<ServiceAppointment> createAppointment({
    required String serviceId,
    String? userId,
    required String vehicleId,
    required String serviceName,
    required DateTime appointmentDate,
    required String timeSlot,
    required String notes,
    required double estimatedPrice,
  }) async {
    final response = await _apiClient.post('/b2c/appointments', data: {
      'serviceId': serviceId,
      if (userId != null) 'userId': userId,
      'vehicleId': vehicleId,
      'serviceName': serviceName,
      'appointmentDate': appointmentDate.toIso8601String(),
      'timeSlot': timeSlot,
      'notes': notes,
      'estimatedPrice': estimatedPrice,
    });
    return ServiceAppointment.fromJson(
      Map<String, dynamic>.from(response.data['data'] as Map),
    );
  }

  Future<List<ServiceAppointment>> getAppointments() async {
    final response = await _apiClient.get('/b2c/appointments');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => ServiceAppointment.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<bool> cancelAppointment(String appointmentId) async {
    final response = await _apiClient.put('/b2c/appointments/$appointmentId/cancel');
    return response.statusCode == 200;
  }
}
