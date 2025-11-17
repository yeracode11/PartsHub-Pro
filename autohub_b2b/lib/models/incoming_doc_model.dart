import 'package:equatable/equatable.dart';

enum IncomingDocStatus {
  draft,
  done,
  cancelled;

  String get displayName {
    switch (this) {
      case IncomingDocStatus.draft:
        return 'Черновик';
      case IncomingDocStatus.done:
        return 'Проведено';
      case IncomingDocStatus.cancelled:
        return 'Отменено';
    }
  }

  static IncomingDocStatus fromString(String? status) {
    switch (status) {
      case 'draft':
        return IncomingDocStatus.draft;
      case 'done':
        return IncomingDocStatus.done;
      case 'cancelled':
        return IncomingDocStatus.cancelled;
      default:
        return IncomingDocStatus.draft;
    }
  }
}

enum IncomingDocType {
  usedParts, // Б/У разбор
  newParts, // Новые запчасти
  ownProduction; // Собственное производство

  String get displayName {
    switch (this) {
      case IncomingDocType.usedParts:
        return 'Б/У разбор';
      case IncomingDocType.newParts:
        return 'Новые запчасти';
      case IncomingDocType.ownProduction:
        return 'Собственное производство';
    }
  }

  static IncomingDocType fromString(String? type) {
    switch (type) {
      case 'used_parts':
        return IncomingDocType.usedParts;
      case 'new_parts':
        return IncomingDocType.newParts;
      case 'own_production':
        return IncomingDocType.ownProduction;
      default:
        return IncomingDocType.newParts;
    }
  }
}

class IncomingDocModel extends Equatable {
  final String id;
  final String docNumber;
  final DateTime date;
  final String? supplierId;
  final String? supplierName;
  final IncomingDocType type;
  final IncomingDocStatus status;
  final String? warehouse;
  final String? notes;
  final List<String>? docPhotos;
  final String createdById;
  final String? createdByName;
  final double totalAmount;
  final List<IncomingItemModel>? items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncomingDocModel({
    required this.id,
    required this.docNumber,
    required this.date,
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.status,
    this.warehouse,
    this.notes,
    this.docPhotos,
    required this.createdById,
    this.createdByName,
    required this.totalAmount,
    this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncomingDocModel.fromJson(Map<String, dynamic> json) {
    return IncomingDocModel(
      id: json['id'] as String,
      docNumber: json['docNumber'] as String,
      date: DateTime.parse(json['date'] as String),
      supplierId: json['supplierId'] as String?,
      supplierName: json['supplier']?['name'] as String? ?? json['supplierName'] as String?,
      type: IncomingDocType.fromString(json['type'] as String?),
      status: IncomingDocStatus.fromString(json['status'] as String?),
      warehouse: json['warehouse'] as String?,
      notes: json['notes'] as String?,
      docPhotos: json['docPhotos'] != null
          ? List<String>.from(json['docPhotos'] as List)
          : null,
      createdById: json['createdById'] as String,
      createdByName: json['createdBy']?['name'] as String?,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((item) => IncomingItemModel.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'docNumber': docNumber,
      'date': date.toIso8601String().split('T')[0],
      'supplierId': supplierId,
      'supplierName': supplierName,
      'type': type.name,
      'status': status.name,
      'warehouse': warehouse,
      'notes': notes,
      'docPhotos': docPhotos,
      'totalAmount': totalAmount,
    };
  }

  @override
  List<Object?> get props => [
        id,
        docNumber,
        date,
        supplierId,
        supplierName,
        type,
        status,
        warehouse,
        notes,
        totalAmount,
      ];
}

