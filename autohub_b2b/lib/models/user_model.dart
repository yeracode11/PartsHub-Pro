import 'package:equatable/equatable.dart';

enum UserRole {
  owner,
  manager,
  storekeeper,
  worker;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'Владелец';
      case UserRole.manager:
        return 'Менеджер';
      case UserRole.storekeeper:
        return 'Кладовщик';
      case UserRole.worker:
        return 'Мастер/Мойщик';
    }
  }
}

enum BusinessType {
  dismantler,
  service,
  carwash;

  String get displayName {
    switch (this) {
      case BusinessType.dismantler:
        return 'Авторазбор';
      case BusinessType.service:
        return 'Автосервис';
      case BusinessType.carwash:
        return 'Автомойка';
    }
  }
}

class UserModel extends Equatable {
  final int? id;
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final BusinessType businessType;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    this.id,
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.businessType,
    this.isActive = true,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    BusinessType? businessType,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      businessType: businessType ?? this.businessType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.name,
      'businessType': businessType.name,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.worker,
      ),
      businessType: BusinessType.values.firstWhere(
        (e) => e.name == json['businessType'],
        orElse: () => BusinessType.service,
      ),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        uid,
        name,
        email,
        role,
        businessType,
        isActive,
        createdAt,
      ];
}

