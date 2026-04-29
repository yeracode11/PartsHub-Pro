import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.organizationId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final String? organizationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      organizationId: json['organizationId']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  List<Object?> get props =>
      [id, email, name, role, isActive, organizationId, createdAt, updatedAt];
}

class UsersPageResult extends Equatable {
  const UsersPageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<UserEntity> items;
  final int total;
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [items, total, page, pageSize];
}
