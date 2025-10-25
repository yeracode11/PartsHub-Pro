import 'package:flutter/material.dart';

class AutoService {
  final String id;
  final String name;
  final String description;
  final String address;
  final String phone;
  final String email;
  final List<String> images;
  final double rating;
  final int reviewCount;
  final List<String> services;
  final List<String> workingHours;
  final Map<String, List<String>> availability; // день недели -> список времени
  final double latitude;
  final double longitude;
  final bool isVerified;
  final List<String> certifications;
  final String website;
  final Map<String, double> servicePrices;

  const AutoService({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.phone,
    required this.email,
    required this.images,
    required this.rating,
    required this.reviewCount,
    required this.services,
    required this.workingHours,
    required this.availability,
    required this.latitude,
    required this.longitude,
    required this.isVerified,
    required this.certifications,
    required this.website,
    required this.servicePrices,
  });

  factory AutoService.fromJson(Map<String, dynamic> json) {
    return AutoService(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      services: List<String>.from(json['services'] ?? []),
      workingHours: List<String>.from(json['workingHours'] ?? []),
      availability: Map<String, List<String>>.from(
        json['availability']?.map((key, value) => MapEntry(key, List<String>.from(value))) ?? {},
      ),
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      isVerified: json['isVerified'] ?? false,
      certifications: List<String>.from(json['certifications'] ?? []),
      website: json['website'] ?? '',
      servicePrices: Map<String, double>.from(
        json['servicePrices']?.map((key, value) => MapEntry(key, value.toDouble())) ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'phone': phone,
      'email': email,
      'images': images,
      'rating': rating,
      'reviewCount': reviewCount,
      'services': services,
      'workingHours': workingHours,
      'availability': availability,
      'latitude': latitude,
      'longitude': longitude,
      'isVerified': isVerified,
      'certifications': certifications,
      'website': website,
      'servicePrices': servicePrices,
    };
  }
}

class ServiceAppointment {
  final String id;
  final String serviceId;
  final String userId;
  final String vehicleId;
  final String serviceName;
  final DateTime appointmentDate;
  final String timeSlot;
  final String status; // pending, confirmed, completed, cancelled
  final String notes;
  final double estimatedPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceAppointment({
    required this.id,
    required this.serviceId,
    required this.userId,
    required this.vehicleId,
    required this.serviceName,
    required this.appointmentDate,
    required this.timeSlot,
    required this.status,
    required this.notes,
    required this.estimatedPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceAppointment.fromJson(Map<String, dynamic> json) {
    return ServiceAppointment(
      id: json['id'] ?? '',
      serviceId: json['serviceId'] ?? '',
      userId: json['userId'] ?? '',
      vehicleId: json['vehicleId'] ?? '',
      serviceName: json['serviceName'] ?? '',
      appointmentDate: DateTime.parse(json['appointmentDate'] ?? DateTime.now().toIso8601String()),
      timeSlot: json['timeSlot'] ?? '',
      status: json['status'] ?? 'pending',
      notes: json['notes'] ?? '',
      estimatedPrice: (json['estimatedPrice'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'userId': userId,
      'vehicleId': vehicleId,
      'serviceName': serviceName,
      'appointmentDate': appointmentDate.toIso8601String(),
      'timeSlot': timeSlot,
      'status': status,
      'notes': notes,
      'estimatedPrice': estimatedPrice,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ServiceAppointment copyWith({
    String? id,
    String? serviceId,
    String? userId,
    String? vehicleId,
    String? serviceName,
    DateTime? appointmentDate,
    String? timeSlot,
    String? status,
    String? notes,
    double? estimatedPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceAppointment(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceName: serviceName ?? this.serviceName,
      appointmentDate: appointmentDate ?? this.appointmentDate,
      timeSlot: timeSlot ?? this.timeSlot,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

extension AppointmentStatusExtension on AppointmentStatus {
  String get displayName {
    switch (this) {
      case AppointmentStatus.pending:
        return 'Ожидает подтверждения';
      case AppointmentStatus.confirmed:
        return 'Подтверждено';
      case AppointmentStatus.completed:
        return 'Завершено';
      case AppointmentStatus.cancelled:
        return 'Отменено';
    }
  }

  Color get color {
    switch (this) {
      case AppointmentStatus.pending:
        return Colors.orange;
      case AppointmentStatus.confirmed:
        return Colors.blue;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.cancelled:
        return Colors.red;
    }
  }
}