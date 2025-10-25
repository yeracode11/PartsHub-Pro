import 'product_model.dart';

class CartItem {
  final Product product;
  final int quantity;
  final DateTime addedAt;

  CartItem({
    required this.product,
    required this.quantity,
    required this.addedAt,
  });

  double get totalPrice => product.price * quantity;
  String get totalPriceFormatted => '${totalPrice.toStringAsFixed(0)} ₸';

  CartItem copyWith({
    Product? product,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product']),
      quantity: json['quantity'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}

class Cart {
  final List<CartItem> items;
  final DateTime lastUpdated;

  Cart({
    required this.items,
    required this.lastUpdated,
  });

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  
  double get totalAmount => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  
  String get totalAmountFormatted => '${totalAmount.toStringAsFixed(0)} ₸';

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  Cart addItem(Product product, {int quantity = 1}) {
    final existingItemIndex = items.indexWhere(
      (item) => item.product.id == product.id,
    );

    List<CartItem> newItems;
    if (existingItemIndex != -1) {
      // Увеличиваем количество существующего товара
      newItems = List.from(items);
      newItems[existingItemIndex] = items[existingItemIndex].copyWith(
        quantity: items[existingItemIndex].quantity + quantity,
      );
    } else {
      // Добавляем новый товар
      newItems = [
        ...items,
        CartItem(
          product: product,
          quantity: quantity,
          addedAt: DateTime.now(),
        ),
      ];
    }

    return Cart(
      items: newItems,
      lastUpdated: DateTime.now(),
    );
  }

  Cart removeItem(int productId) {
    return Cart(
      items: items.where((item) => item.product.id != productId).toList(),
      lastUpdated: DateTime.now(),
    );
  }

  Cart updateQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }

    final newItems = items.map((item) {
      if (item.product.id == productId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    return Cart(
      items: newItems,
      lastUpdated: DateTime.now(),
    );
  }

  Cart clear() {
    return Cart(
      items: [],
      lastUpdated: DateTime.now(),
    );
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => CartItem.fromJson(item))
          .toList() ?? [],
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
