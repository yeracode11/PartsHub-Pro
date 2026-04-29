import 'package:equatable/equatable.dart';

class SubscriptionEntity extends Equatable {
  const SubscriptionEntity({
    required this.id,
    required this.userId,
    this.plan,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String? plan;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory SubscriptionEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    return SubscriptionEntity(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      plan: json['plan'] as String? ?? json['planId'] as String? ?? json['plan_code'] as String?,
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
      expiresAt: parse(json['expiresAt'] ?? json['expires_at']),
      createdAt: parse(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toPatchBody({
    String? plan,
    bool? isActive,
    DateTime? expiresAt,
  }) {
    return {
      if (plan != null) 'plan': plan,
      if (isActive != null) 'isActive': isActive,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, userId, plan, isActive, expiresAt, createdAt];
}
