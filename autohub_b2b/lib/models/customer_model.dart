import 'package:equatable/equatable.dart';

class CustomerModel extends Equatable {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? carBrand;
  final String? carModel;
  final String? carYear;
  final String? vin;
  final String? notes;
  final bool synced;
  final DateTime createdAt;

  const CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.carBrand,
    this.carModel,
    this.carYear,
    this.vin,
    this.notes,
    this.synced = false,
    required this.createdAt,
  });

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? carBrand,
    String? carModel,
    String? carYear,
    String? vin,
    String? notes,
    bool? synced,
    DateTime? createdAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      carBrand: carBrand ?? this.carBrand,
      carModel: carModel ?? this.carModel,
      carYear: carYear ?? this.carYear,
      vin: vin ?? this.vin,
      notes: notes ?? this.notes,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'carBrand': carBrand,
      'carModel': carModel,
      'carYear': carYear,
      'vin': vin,
      'notes': notes,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String?,
      carBrand: json['carBrand'] as String?,
      carModel: json['carModel'] as String?,
      carYear: json['carYear'] as String?,
      vin: json['vin'] as String?,
      notes: json['notes'] as String?,
      synced: json['synced'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        email,
        carBrand,
        carModel,
        carYear,
        vin,
        notes,
        synced,
        createdAt,
      ];
}

