import 'package:equatable/equatable.dart';

class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.organizationId,
  });

  final String id;
  final String email;
  final String role;
  final String? name;
  final String? organizationId;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      name: json['name'] as String?,
      organizationId: json['organizationId']?.toString(),
    );
  }

  bool get isSuperadmin => role == 'superadmin';

  @override
  List<Object?> get props => [id, email, role, name, organizationId];
}

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final AdminUser user;

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
