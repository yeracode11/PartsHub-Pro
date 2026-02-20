import 'package:equatable/equatable.dart';

class ItemModel extends Equatable {
  final int? id;
  final String name;
  final String? category;
  final String? sku;
  final double price;
  final int quantity;
  final String condition;
  final String? description;
  final String? imageUrl;
  final List<String>? images;
  final String? warehouseCell;
  final String? warehouseId;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemModel({
    this.id,
    required this.name,
    this.category,
    this.sku,
    required this.price,
    required this.quantity,
    required this.condition,
    this.description,
    this.imageUrl,
    this.images,
    this.warehouseCell,
    this.warehouseId,
    this.synced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ItemModel copyWith({
    int? id,
    String? name,
    String? category,
    String? sku,
    double? price,
    int? quantity,
    String? condition,
    String? description,
    String? imageUrl,
    List<String>? images,
    String? warehouseCell,
    String? warehouseId,
    bool? synced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      warehouseCell: warehouseCell ?? this.warehouseCell,
      warehouseId: warehouseId ?? this.warehouseId,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'sku': sku,
      'price': price,
      'quantity': quantity,
      'condition': condition,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'warehouseCell': warehouseCell,
      'warehouseId': warehouseId,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    try {
      // Обработка price (может быть string из PostgreSQL decimal)
      final priceValue = json['price'];
      final double price;
      if (priceValue is String) {
        price = double.tryParse(priceValue) ?? 0.0;
      } else if (priceValue is num) {
        price = priceValue.toDouble();
      } else {
        price = 0.0;
      }

      // Обработка дат
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        if (dateValue is DateTime) return dateValue;
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            return null;
          }
        }
        return null;
      }

      return ItemModel(
        id: json['id'] is int ? json['id'] : (json['id'] is String ? int.tryParse(json['id']) : null),
        name: json['name'] as String? ?? 'Без названия',
        category: json['category'] as String?,
        sku: json['sku'] as String?,
        price: price,
        quantity: json['quantity'] is int ? json['quantity'] : (json['quantity'] is num ? json['quantity'].toInt() : 0),
        condition: json['condition'] as String? ?? 'new',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        images: json['images'] != null 
            ? (json['images'] is List ? List<String>.from(json['images'].map((e) => e.toString())) : null)
            : null,
        warehouseCell: json['warehouseCell'] as String?,
        warehouseId: json['warehouseId'] as String?,
        synced: json['synced'] is bool ? json['synced'] : false,
        createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
        updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  List<Object?> get props => [
        id,
        name,
        category,
        sku,
        price,
        quantity,
        condition,
        description,
        imageUrl,
        images,
        warehouseCell,
        warehouseId,
        synced,
        createdAt,
        updatedAt,
      ];
}

