class Product {
  final int id;
  final String name;
  final String description;
  final String category;
  final String brand;
  final String sku;
  final double price;
  final int stock;
  final String condition;
  final List<String> images;
  final String? sellerName;
  final int? sellerId;
  final double rating;
  final int reviewCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.brand,
    required this.sku,
    required this.price,
    required this.stock,
    required this.condition,
    required this.images,
    this.sellerName,
    this.sellerId,
    required this.rating,
    required this.reviewCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'] ?? 'Без названия',
      description: json['description'] ?? 'Описание отсутствует',
      category: json['category'] ?? 'Без категории',
      brand: json['brand'] ?? 'Неизвестный бренд',
      sku: json['sku'] ?? 'N/A',
      price: (json['price'] ?? 0).toDouble(),
      stock: json['stock'] ?? 0,
      condition: json['condition'] ?? 'new',
      images: List<String>.from(json['images'] ?? []),
      sellerName: json['sellerName'],
      sellerId: json['sellerId'] is String 
          ? int.tryParse(json['sellerId']) 
          : json['sellerId'],
      rating: (json['rating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'brand': brand,
      'sku': sku,
      'price': price,
      'stock': stock,
      'condition': condition,
      'images': images,
      'sellerName': sellerName,
      'sellerId': sellerId,
      'rating': rating,
      'reviewCount': reviewCount,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  bool get isInStock => stock > 0;
  String get priceFormatted => '${price.toStringAsFixed(0)} ₸';
}

class Order {
  final int id;
  final String orderNumber;
  final int? customerId;
  final List<OrderItem> items;
  final double totalAmount;
  final String status; // pending, processing, shipped, delivered, cancelled
  final String paymentStatus; // pending, paid, failed
  final String? shippingAddress;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.orderNumber,
    this.customerId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    this.shippingAddress,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      orderNumber: json['orderNumber'],
      customerId: json['customerId'],
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item))
          .toList() ?? [],
      totalAmount: json['totalAmount'] is String 
          ? double.parse(json['totalAmount']) 
          : (json['totalAmount'] ?? 0).toDouble(),
      status: json['status'],
      paymentStatus: json['paymentStatus'],
      shippingAddress: json['shippingAddress'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerId': customerId,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount.toStringAsFixed(2),
      'status': status,
      'paymentStatus': paymentStatus,
      'shippingAddress': shippingAddress,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String get totalFormatted => '${totalAmount.toStringAsFixed(0)} ₸';
}

class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double total;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      productImage: json['productImage'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      total: (json['total'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'total': total,
    };
  }

  String get priceFormatted => '${price.toStringAsFixed(0)} ₸';
  String get totalFormatted => '${total.toStringAsFixed(0)} ₸';
}
