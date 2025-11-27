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
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    // Обработка price (может быть string из PostgreSQL decimal)
    final priceValue = json['price'];
    final double price;
    if (priceValue is String) {
      price = double.parse(priceValue);
    } else if (priceValue is num) {
      price = priceValue.toDouble();
    } else {
      price = 0.0;
    }

    return ItemModel(
      id: json['id'] as int?,
      name: json['name'] as String? ?? 'Без названия',
      category: json['category'] as String?,
      sku: json['sku'] as String?,
      price: price,
      quantity: json['quantity'] as int? ?? 0,
      condition: json['condition'] as String? ?? 'new',
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      images: json['images'] != null 
          ? List<String>.from(json['images'] as List)
          : null,
      warehouseCell: json['warehouseCell'] as String?,
      synced: json['synced'] as bool? ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
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
        synced,
        createdAt,
        updatedAt,
      ];
}

