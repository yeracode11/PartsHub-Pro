import 'package:equatable/equatable.dart';

class IncomingItemModel extends Equatable {
  final String id;
  final String docId;
  final int? itemId;
  final String name;
  final String? category;
  final String? carBrand;
  final String? carModel;
  final String? vin;
  final String? condition;
  final int quantity;
  final double purchasePrice;
  final String? warehouseCell;
  final List<String>? photos;
  final String? sku;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IncomingItemModel({
    required this.id,
    required this.docId,
    this.itemId,
    required this.name,
    this.category,
    this.carBrand,
    this.carModel,
    this.vin,
    this.condition,
    required this.quantity,
    required this.purchasePrice,
    this.warehouseCell,
    this.photos,
    this.sku,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IncomingItemModel.fromJson(Map<String, dynamic> json) {
    return IncomingItemModel(
      id: json['id'] as String,
      docId: json['docId'] as String,
      itemId: json['itemId'] as int?,
      name: json['name'] as String,
      category: json['category'] as String?,
      carBrand: json['carBrand'] as String?,
      carModel: json['carModel'] as String?,
      vin: json['vin'] as String?,
      condition: json['condition'] as String?,
      quantity: json['quantity'] as int,
      purchasePrice: (json['purchasePrice'] as num).toDouble(),
      warehouseCell: json['warehouseCell'] as String?,
      photos: json['photos'] != null
          ? List<String>.from(json['photos'] as List)
          : null,
      sku: json['sku'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'category': category,
      'carBrand': carBrand,
      'carModel': carModel,
      'vin': vin,
      'condition': condition,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'warehouseCell': warehouseCell,
      'photos': photos,
      'sku': sku,
    };
  }

  @override
  List<Object?> get props => [
        id,
        docId,
        itemId,
        name,
        quantity,
        purchasePrice,
      ];
}

