class Warehouse {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? contactPerson;
  final bool isActive;
  final String organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Warehouse({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.contactPerson,
    this.isActive = true,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) {
    return Warehouse(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      contactPerson: json['contactPerson'],
      isActive: json['isActive'] ?? true,
      organizationId: json['organizationId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'contactPerson': contactPerson,
      'isActive': isActive,
      'organizationId': organizationId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Warehouse copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? contactPerson,
    bool? isActive,
    String? organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      contactPerson: contactPerson ?? this.contactPerson,
      isActive: isActive ?? this.isActive,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WarehouseTransfer {
  final String id;
  final String organizationId;
  final String fromWarehouseId;
  final String toWarehouseId;
  final int itemId;
  final int quantity;
  final TransferStatus status;
  final String? notes;
  final String? createdByUserId;
  final String? completedByUserId;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Связанные объекты (загружаются отдельно)
  final Warehouse? fromWarehouse;
  final Warehouse? toWarehouse;
  final Map<String, dynamic>? item;

  WarehouseTransfer({
    required this.id,
    required this.organizationId,
    required this.fromWarehouseId,
    required this.toWarehouseId,
    required this.itemId,
    required this.quantity,
    required this.status,
    this.notes,
    this.createdByUserId,
    this.completedByUserId,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fromWarehouse,
    this.toWarehouse,
    this.item,
  });

  factory WarehouseTransfer.fromJson(Map<String, dynamic> json) {
    return WarehouseTransfer(
      id: json['id'],
      organizationId: json['organizationId'],
      fromWarehouseId: json['fromWarehouseId'],
      toWarehouseId: json['toWarehouseId'],
      itemId: json['itemId'],
      quantity: json['quantity'],
      status: TransferStatus.fromString(json['status']),
      notes: json['notes'],
      createdByUserId: json['createdByUserId'],
      completedByUserId: json['completedByUserId'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      fromWarehouse: json['fromWarehouse'] != null ? Warehouse.fromJson(json['fromWarehouse']) : null,
      toWarehouse: json['toWarehouse'] != null ? Warehouse.fromJson(json['toWarehouse']) : null,
      item: json['item'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizationId': organizationId,
      'fromWarehouseId': fromWarehouseId,
      'toWarehouseId': toWarehouseId,
      'itemId': itemId,
      'quantity': quantity,
      'status': status.toString(),
      'notes': notes,
      'createdByUserId': createdByUserId,
      'completedByUserId': completedByUserId,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

enum TransferStatus {
  draft,
  inTransit,
  completed,
  cancelled;

  static TransferStatus fromString(String value) {
    switch (value) {
      case 'draft':
        return TransferStatus.draft;
      case 'in_transit':
        return TransferStatus.inTransit;
      case 'completed':
        return TransferStatus.completed;
      case 'cancelled':
        return TransferStatus.cancelled;
      default:
        return TransferStatus.draft;
    }
  }

  @override
  String toString() {
    switch (this) {
      case TransferStatus.draft:
        return 'draft';
      case TransferStatus.inTransit:
        return 'in_transit';
      case TransferStatus.completed:
        return 'completed';
      case TransferStatus.cancelled:
        return 'cancelled';
    }
  }

  String getDisplayName() {
    switch (this) {
      case TransferStatus.draft:
        return 'Черновик';
      case TransferStatus.inTransit:
        return 'В пути';
      case TransferStatus.completed:
        return 'Завершено';
      case TransferStatus.cancelled:
        return 'Отменено';
    }
  }
}

