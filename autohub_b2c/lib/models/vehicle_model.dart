import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';

enum FuelType {
  petrol,
  diesel,
  electric,
  hybrid,
}

enum TransmissionType {
  manual,
  automatic,
  robot,
  cvt,
}

class Vehicle {
  final int id;
  final String brand;
  final String model;
  final int year;
  final String? color;
  final String plateNumber;
  final String? vin;
  final FuelType fuelType;
  final TransmissionType transmission;
  final String? engineVolume;
  final int? enginePower;
  final int currentMileage;
  final int? lastServiceMileage;
  final DateTime? lastServiceDate;
  final int? nextServiceMileage;
  final DateTime? nextServiceDate;
  final String? notes;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plateNumber,
    this.color,
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      plateNumber: json['plateNumber'],
      color: json['color'],
      vin: json['vin'],
      fuelType: FuelType.values.firstWhere(
        (e) => e.toString().split('.').last == json['fuelType'],
        orElse: () => FuelType.petrol,
      ),
      transmission: TransmissionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['transmission'],
        orElse: () => TransmissionType.manual,
      ),
      engineVolume: json['engineVolume'],
      enginePower: json['enginePower'],
      currentMileage: json['currentMileage'] ?? 0,
      lastServiceMileage: json['lastServiceMileage'],
      lastServiceDate: _parseDate(json['lastServiceDate']),
      nextServiceMileage: json['nextServiceMileage'],
      nextServiceDate: _parseDate(json['nextServiceDate']),
      notes: json['notes'],
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'].toString()),
      updatedAt: DateTime.parse(json['updatedAt'].toString()),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString();
    if (raw.isEmpty) return null;
    return DateTime.parse(raw.contains('T') ? raw : '${raw}T00:00:00');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'year': year,
      'plateNumber': plateNumber,
      'color': color,
      'vin': vin,
      'fuelType': fuelType.toString().split('.').last,
      'transmission': transmission.toString().split('.').last,
      'engineVolume': engineVolume,
      'enginePower': enginePower,
      'currentMileage': currentMileage,
      'lastServiceMileage': lastServiceMileage,
      'lastServiceDate': lastServiceDate?.toIso8601String(),
      'nextServiceMileage': nextServiceMileage,
      'nextServiceDate': nextServiceDate?.toIso8601String(),
      'notes': notes,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get fullName => '$brand $model $year';

  String get fuelTypeDisplay => switch (fuelType) {
    FuelType.petrol => 'Бензин',
    FuelType.diesel => 'Дизель',
    FuelType.electric => 'Электро',
    FuelType.hybrid => 'Гибрид',
  };

  String get transmissionDisplay => switch (transmission) {
    TransmissionType.manual => 'МКПП',
    TransmissionType.automatic => 'АКПП',
    TransmissionType.robot => 'Робот',
    TransmissionType.cvt => 'Вариатор',
  };

  int get mileageToService {
    if (nextServiceMileage == null) return 0;
    return nextServiceMileage! - currentMileage;
  }

  bool get needsService => mileageToService <= 1000;

  String get serviceStatus {
    if (nextServiceMileage == null) return 'Не запланировано';
    if (needsService) return 'Требуется ТО';
    return 'В норме';
  }

  Color get serviceStatusColor {
    if (nextServiceMileage == null) return Colors.grey;
    if (needsService) return Colors.red;
    return Colors.green;
  }

  int get healthScore {
    var score = 100;
    if (needsService) score -= 28;
    if (nextServiceDate != null &&
        nextServiceDate!.isBefore(DateTime.now())) {
      score -= 22;
    }
    if (mileageToService > 0 && mileageToService < 3000) score -= 10;
    if (currentMileage > 200000) score -= 8;
    return score.clamp(0, 100);
  }

  Color get healthColor {
    if (healthScore >= 75) return AppColors.healthGood;
    if (healthScore >= 50) return AppColors.healthMid;
    return AppColors.healthBad;
  }

  String get healthLabel {
    if (healthScore >= 75) return 'Отличное состояние';
    if (healthScore >= 50) return 'Требует внимания';
    return 'Нужно обслуживание';
  }
}