class VehicleModel {
  final int id;
  final String organizationId;
  final int customerId;
  final String customerName;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String plateNumber;
  final String? vin;
  final String fuelType;
  final String transmission;
  final String? engineVolume;
  final int? enginePower;
  final int currentMileage;
  final int? lastServiceMileage;
  final DateTime? lastServiceDate;
  final int? nextServiceMileage;
  final DateTime? nextServiceDate;
  final String? notes;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // История заказов (опционально)
  final List<dynamic>? orders;

  VehicleModel({
    required this.id,
    required this.organizationId,
    required this.customerId,
    required this.customerName,
    required this.brand,
    required this.model,
    required this.year,
    this.color,
    required this.plateNumber,
    this.vin,
    required this.fuelType,
    required this.transmission,
    this.engineVolume,
    this.enginePower,
    required this.currentMileage,
    this.lastServiceMileage,
    this.lastServiceDate,
    this.nextServiceMileage,
    this.nextServiceDate,
    this.notes,
    this.photoUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.orders,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      organizationId: json['organizationId'] as String,
      customerId: json['customerId'] as int,
      customerName: json['customer'] != null
          ? json['customer']['name'] as String
          : 'Неизвестный клиент',
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int,
      color: json['color'] as String?,
      plateNumber: json['plateNumber'] as String,
      vin: json['vin'] as String?,
      fuelType: json['fuelType'] as String,
      transmission: json['transmission'] as String,
      engineVolume: json['engineVolume'] as String?,
      enginePower: json['enginePower'] as int?,
      currentMileage: json['currentMileage'] as int,
      lastServiceMileage: json['lastServiceMileage'] as int?,
      lastServiceDate: json['lastServiceDate'] != null
          ? DateTime.parse(json['lastServiceDate'] as String)
          : null,
      nextServiceMileage: json['nextServiceMileage'] as int?,
      nextServiceDate: json['nextServiceDate'] != null
          ? DateTime.parse(json['nextServiceDate'] as String)
          : null,
      notes: json['notes'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      orders: json['orders'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'customerId': customerId,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'plateNumber': plateNumber,
      'vin': vin,
      'fuelType': fuelType,
      'transmission': transmission,
      'engineVolume': engineVolume,
      'enginePower': enginePower,
      'currentMileage': currentMileage,
      'lastServiceMileage': lastServiceMileage,
      'lastServiceDate': lastServiceDate?.toIso8601String(),
      'nextServiceMileage': nextServiceMileage,
      'nextServiceDate': nextServiceDate?.toIso8601String(),
      'notes': notes,
      'photoUrl': photoUrl,
      'isActive': isActive,
    };
  }

  String get displayName => '$brand $model ($year)';
  
  String get fuelTypeDisplay {
    switch (fuelType) {
      case 'petrol':
        return 'Бензин';
      case 'diesel':
        return 'Дизель';
      case 'electric':
        return 'Электро';
      case 'hybrid':
        return 'Гибрид';
      case 'gas':
        return 'Газ';
      default:
        return fuelType;
    }
  }

  String get transmissionDisplay {
    switch (transmission) {
      case 'manual':
        return 'Механика';
      case 'automatic':
        return 'Автомат';
      case 'robot':
        return 'Робот';
      case 'cvt':
        return 'Вариатор';
      default:
        return transmission;
    }
  }

  // Проверка: нужно ли ТО?
  bool get needsService {
    final now = DateTime.now();
    
    // Проверка по дате
    if (nextServiceDate != null && nextServiceDate!.isBefore(now)) {
      return true;
    }
    
    // Проверка по пробегу (осталось менее 1000 км)
    if (nextServiceMileage != null && 
        (nextServiceMileage! - currentMileage) <= 1000) {
      return true;
    }
    
    return false;
  }

  // Осталось км до ТО
  int? get kmUntilService {
    if (nextServiceMileage == null) return null;
    return nextServiceMileage! - currentMileage;
  }

  // Осталось дней до ТО
  int? get daysUntilService {
    if (nextServiceDate == null) return null;
    return nextServiceDate!.difference(DateTime.now()).inDays;
  }
}

