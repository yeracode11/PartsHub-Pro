import 'package:equatable/equatable.dart';

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    this.userId,
    this.amount,
    this.currency,
    this.status,
    this.createdAt,
    this.metadata,
  });

  final String id;
  final String? userId;
  final double? amount;
  final String? currency;
  final String? status;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  factory TransactionEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) => v is String ? DateTime.tryParse(v) : null;
    double? amt;
    final rawAmt = json['amount'] ?? json['total'];
    if (rawAmt is num) amt = rawAmt.toDouble();
    return TransactionEntity(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      amount: amt,
      currency: json['currency'] as String?,
      status: json['status'] as String?,
      createdAt: parse(json['createdAt'] ?? json['created_at']),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
    );
  }

  @override
  List<Object?> get props => [id, userId, amount, currency, status, createdAt, metadata];
}
