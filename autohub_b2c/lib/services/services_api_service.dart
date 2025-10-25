import 'package:dio/dio.dart';
import '../models/service_model.dart';
import 'api_client.dart';

class ServicesApiService {
  final ApiClient _apiClient;

  ServicesApiService(this._apiClient);

  // Получить список автосервисов
  Future<List<AutoService>> getServices({
    String? search,
    String? category,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (category != null && category.isNotEmpty) {
        queryParams['category'] = category;
      }
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude;
        queryParams['longitude'] = longitude;
        queryParams['radius'] = radius ?? 10.0; // радиус в км
      }

      final response = await _apiClient.get('/b2c/services', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => AutoService.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load services');
      }
    } catch (e) {
      // Если API недоступен, используем моковые данные
      print('API недоступен, используем моковые данные: $e');
      return _getMockServices();
    }
  }

  // Получить детали автосервиса
  Future<AutoService> getServiceById(String serviceId) async {
    try {
      final response = await _apiClient.get('/services/$serviceId');
      
      if (response.statusCode == 200) {
        return AutoService.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to load service details');
      }
    } catch (e) {
      // Возвращаем моковые данные для демонстрации
      return _getMockServices().firstWhere((service) => service.id == serviceId);
    }
  }

  // Получить доступные слоты времени
  Future<List<String>> getAvailableTimeSlots(String serviceId, DateTime date) async {
    try {
      final response = await _apiClient.get(
        '/services/$serviceId/availability',
        queryParameters: {
          'date': date.toIso8601String().split('T')[0],
        },
      );
      
      if (response.statusCode == 200) {
        return List<String>.from(response.data['timeSlots'] ?? []);
      } else {
        throw Exception('Failed to load available time slots');
      }
    } catch (e) {
      // Возвращаем моковые данные для демонстрации
      return _getMockTimeSlots();
    }
  }

  // Создать запись на сервис
  Future<ServiceAppointment> createAppointment({
    required String serviceId,
    required String userId,
    required String vehicleId,
    required String serviceName,
    required DateTime appointmentDate,
    required String timeSlot,
    required String notes,
    required double estimatedPrice,
  }) async {
    try {
      final response = await _apiClient.post('/appointments', data: {
        'serviceId': serviceId,
        'userId': userId,
        'vehicleId': vehicleId,
        'serviceName': serviceName,
        'appointmentDate': appointmentDate.toIso8601String(),
        'timeSlot': timeSlot,
        'notes': notes,
        'estimatedPrice': estimatedPrice,
      });
      
      if (response.statusCode == 201) {
        return ServiceAppointment.fromJson(response.data['data']);
      } else {
        throw Exception('Failed to create appointment');
      }
    } catch (e) {
      // Возвращаем моковые данные для демонстрации
      return ServiceAppointment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        serviceId: serviceId,
        userId: userId,
        vehicleId: vehicleId,
        serviceName: serviceName,
        appointmentDate: appointmentDate,
        timeSlot: timeSlot,
        status: 'pending',
        notes: notes,
        estimatedPrice: estimatedPrice,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  // Получить записи пользователя
  Future<List<ServiceAppointment>> getUserAppointments(String userId) async {
    try {
      final response = await _apiClient.get('/users/$userId/appointments');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => ServiceAppointment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user appointments');
      }
    } catch (e) {
      // Возвращаем моковые данные для демонстрации
      return _getMockAppointments();
    }
  }

  // Отменить запись
  Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final response = await _apiClient.put('/appointments/$appointmentId/cancel');
      
      return response.statusCode == 200;
    } catch (e) {
      // Для демонстрации возвращаем true
      return true;
    }
  }

  // Моковые данные для демонстрации
  List<AutoService> _getMockServices() {
    return [
      AutoService(
        id: '1',
        name: 'Автосервис "Мастер"',
        description: 'Полный спектр услуг по ремонту и обслуживанию автомобилей. Работаем с 2005 года.',
        address: 'ул. Абая 150, Алматы',
        phone: '+7 (727) 123-45-67',
        email: 'info@master-auto.kz',
        images: [
          'https://images.unsplash.com/photo-1486754735734-325b5831c3ad?w=500',
          'https://images.unsplash.com/photo-1580414772603-1c8b4a0b8b8b?w=500',
        ],
        rating: 4.8,
        reviewCount: 156,
        services: ['Диагностика', 'ТО', 'Ремонт двигателя', 'Замена масла', 'Шиномонтаж'],
        workingHours: ['Пн-Пт: 9:00-18:00', 'Сб: 9:00-15:00', 'Вс: выходной'],
        availability: {
          'monday': ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
          'tuesday': ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
          'wednesday': ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
          'thursday': ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
          'friday': ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'],
          'saturday': ['09:00', '10:00', '11:00', '14:00'],
          'sunday': [],
        },
        latitude: 43.2220,
        longitude: 76.8512,
        isVerified: true,
        certifications: ['ISO 9001', 'Автосервис Казахстана'],
        website: 'https://master-auto.kz',
        servicePrices: {
          'Диагностика': 5000.0,
          'ТО': 15000.0,
          'Ремонт двигателя': 50000.0,
          'Замена масла': 8000.0,
          'Шиномонтаж': 3000.0,
        },
      ),
      AutoService(
        id: '2',
        name: 'СТО "АвтоДоктор"',
        description: 'Современный автосервис с новейшим оборудованием. Специализируемся на европейских автомобилях.',
        address: 'пр. Достык 123, Алматы',
        phone: '+7 (727) 234-56-78',
        email: 'contact@autodoctor.kz',
        images: [
          'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=500',
          'https://images.unsplash.com/photo-1580414772603-1c8b4a0b8b8b?w=500',
        ],
        rating: 4.6,
        reviewCount: 89,
        services: ['Диагностика', 'Ремонт АКПП', 'Кузовной ремонт', 'Покраска', 'Детейлинг'],
        workingHours: ['Пн-Пт: 8:00-19:00', 'Сб: 8:00-16:00', 'Вс: 9:00-14:00'],
        availability: {
          'monday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'],
          'tuesday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'],
          'wednesday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'],
          'thursday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'],
          'friday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00'],
          'saturday': ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00'],
          'sunday': ['09:00', '10:00', '11:00', '13:00'],
        },
        latitude: 43.2389,
        longitude: 76.8897,
        isVerified: true,
        certifications: ['Автосервис Казахстана', 'Европейские стандарты'],
        website: 'https://autodoctor.kz',
        servicePrices: {
          'Диагностика': 6000.0,
          'Ремонт АКПП': 80000.0,
          'Кузовной ремонт': 30000.0,
          'Покраска': 25000.0,
          'Детейлинг': 12000.0,
        },
      ),
      AutoService(
        id: '3',
        name: 'Автоцентр "Экспресс"',
        description: 'Быстрое обслуживание и ремонт. Гарантия качества и доступные цены.',
        address: 'ул. Сатпаева 45, Алматы',
        phone: '+7 (727) 345-67-89',
        email: 'service@express-auto.kz',
        images: [
          'https://images.unsplash.com/photo-1486754735734-325b5831c3ad?w=500',
          'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=500',
        ],
        rating: 4.4,
        reviewCount: 203,
        services: ['Быстрая диагностика', 'Замена фильтров', 'Ремонт тормозов', 'Электрика', 'Кондиционер'],
        workingHours: ['Пн-Вс: 7:00-20:00'],
        availability: {
          'monday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'tuesday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'wednesday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'thursday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'friday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'saturday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
          'sunday': ['07:00', '08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00', '18:00'],
        },
        latitude: 43.2565,
        longitude: 76.9285,
        isVerified: false,
        certifications: ['Автосервис Казахстана'],
        website: 'https://express-auto.kz',
        servicePrices: {
          'Быстрая диагностика': 3000.0,
          'Замена фильтров': 5000.0,
          'Ремонт тормозов': 20000.0,
          'Электрика': 15000.0,
          'Кондиционер': 12000.0,
        },
      ),
    ];
  }

  List<String> _getMockTimeSlots() {
    return [
      '09:00',
      '10:00',
      '11:00',
      '14:00',
      '15:00',
      '16:00',
      '17:00',
    ];
  }

  List<ServiceAppointment> _getMockAppointments() {
    return [
      ServiceAppointment(
        id: '1',
        serviceId: '1',
        userId: 'user1',
        vehicleId: 'vehicle1',
        serviceName: 'Диагностика',
        appointmentDate: DateTime.now().add(const Duration(days: 2)),
        timeSlot: '10:00',
        status: 'confirmed',
        notes: 'Проверить двигатель, есть странные звуки',
        estimatedPrice: 5000.0,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ServiceAppointment(
        id: '2',
        serviceId: '2',
        userId: 'user1',
        vehicleId: 'vehicle1',
        serviceName: 'ТО',
        appointmentDate: DateTime.now().add(const Duration(days: 7)),
        timeSlot: '14:00',
        status: 'pending',
        notes: 'Плановое ТО через 10000 км',
        estimatedPrice: 15000.0,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }
}
