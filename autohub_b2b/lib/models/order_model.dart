import 'package:equatable/equatable.dart';

class OrderModel extends Equatable {
  final int? id;
  final String? orderNumber;
  final int? customerId;
  final double total;
  final String status;
  final String paymentStatus;
  final String? notes;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    this.id,
    this.orderNumber,
    this.customerId,
    required this.total,
    required this.status,
    required this.paymentStatus,
    this.notes,
    this.synced = false,
    required this.createdAt,
    required this.updatedAt,
  });

  OrderModel copyWith({
    int? id,
    String? orderNumber,
    int? customerId,
    double? total,
    String? status,
    String? paymentStatus,
    String? notes,
    bool? synced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      total: total ?? this.total,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'total': total,
      'status': status,
      'paymentStatus': paymentStatus,
      'notes': notes,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Обработка totalAmount (может быть string из PostgreSQL decimal)
    final totalValue = json['total'] ?? json['totalAmount'];
    final double total;
    if (totalValue is String) {
      total = double.parse(totalValue);
    } else if (totalValue is num) {
      total = totalValue.toDouble();
    } else {
      total = 0.0;
    }

    return OrderModel(
      id: json['id'] as int?,
      orderNumber: json['orderNumber'] as String?,
      customerId: json['customerId'] as int?,
      total: total,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      synced: json['synced'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        customerId,
        total,
        status,
        paymentStatus,
        notes,
        synced,
        createdAt,
        updatedAt,
      ];
}

