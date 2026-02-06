import 'package:equatable/equatable.dart';

class OrderItemModel {
  final int id;
  final int itemId;
  final int quantity;
  final double priceAtTime;
  final double subtotal;
  final Map<String, dynamic>? item; // Информация о товаре (name, images, etc.)

  OrderItemModel({
    required this.id,
    required this.itemId,
    required this.quantity,
    required this.priceAtTime,
    required this.subtotal,
    this.item,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final priceAtTimeValue = json['priceAtTime'] ?? json['price_at_time'];
    final subtotalValue = json['subtotal'] ?? 0;
    
    final double priceAtTime;
    if (priceAtTimeValue is String) {
      priceAtTime = double.parse(priceAtTimeValue);
    } else if (priceAtTimeValue is num) {
      priceAtTime = priceAtTimeValue.toDouble();
    } else {
      priceAtTime = 0.0;
    }

    final double subtotal;
    if (subtotalValue is String) {
      subtotal = double.parse(subtotalValue);
    } else if (subtotalValue is num) {
      subtotal = subtotalValue.toDouble();
    } else {
      subtotal = 0.0;
    }

    return OrderItemModel(
      id: json['id'] as int,
      itemId: json['itemId'] as int? ?? json['item_id'] as int,
      quantity: json['quantity'] as int,
      priceAtTime: priceAtTime,
      subtotal: subtotal,
      item: json['item'] as Map<String, dynamic>?,
    );
  }
}

class WorkStageItemModel {
  final String id;
  final String title;
  final bool done;
  final String? doneAt;

  WorkStageItemModel({
    required this.id,
    required this.title,
    required this.done,
    this.doneAt,
  });

  factory WorkStageItemModel.fromJson(Map<String, dynamic> json) {
    return WorkStageItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      done: json['done'] == true,
      doneAt: json['doneAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'done': done,
      'doneAt': doneAt,
    };
  }
}

class WorkStageModel {
  final String id;
  final String title;
  final List<WorkStageItemModel> items;

  WorkStageModel({
    required this.id,
    required this.title,
    required this.items,
  });

  factory WorkStageModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? [];
    return WorkStageModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      items: itemsJson
          .map((item) =>
              WorkStageItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class OrderModel extends Equatable {
  final int? id;
  final String? orderNumber;
  final int? customerId;
  final double total;
  final String status;
  final String paymentStatus;
  final String? notes;
  final String? shippingAddress;
  final bool synced;
  final bool isB2C;
  final List<OrderItemModel>? items;
  final Map<String, dynamic>? customer;
  final List<WorkStageModel>? workStages;
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
    this.shippingAddress,
    this.synced = false,
    this.isB2C = false,
    this.items,
    this.customer,
    this.workStages,
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
    String? shippingAddress,
    bool? synced,
    bool? isB2C,
    List<OrderItemModel>? items,
    Map<String, dynamic>? customer,
    List<WorkStageModel>? workStages,
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
      shippingAddress: shippingAddress ?? this.shippingAddress,
      synced: synced ?? this.synced,
      isB2C: isB2C ?? this.isB2C,
      items: items ?? this.items,
      customer: customer ?? this.customer,
      workStages: workStages ?? this.workStages,
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
      'shippingAddress': shippingAddress,
      'synced': synced,
      'isB2C': isB2C,
      'items': items?.map((item) => {
        'id': item.id,
        'itemId': item.itemId,
        'quantity': item.quantity,
        'priceAtTime': item.priceAtTime,
        'subtotal': item.subtotal,
        'item': item.item,
      }).toList(),
      'customer': customer,
      'workStages': workStages?.map((stage) => stage.toJson()).toList(),
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

    // Парсим items
    List<OrderItemModel>? items;
    if (json['items'] != null) {
      items = (json['items'] as List)
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<WorkStageModel>? workStages;
    if (json['workStages'] != null) {
      workStages = (json['workStages'] as List)
          .map((stage) =>
              WorkStageModel.fromJson(stage as Map<String, dynamic>))
          .toList();
    }

    return OrderModel(
      id: json['id'] as int?,
      orderNumber: json['orderNumber'] as String?,
      customerId: json['customerId'] as int?,
      total: total,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      shippingAddress: json['shippingAddress'] as String?,
      synced: json['synced'] as bool? ?? false,
      isB2C: json['isB2C'] as bool? ?? false,
      items: items,
      customer: json['customer'] as Map<String, dynamic>?,
      workStages: workStages,
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
        shippingAddress,
        synced,
        isB2C,
        items,
        customer,
        workStages,
        createdAt,
        updatedAt,
      ];
}

