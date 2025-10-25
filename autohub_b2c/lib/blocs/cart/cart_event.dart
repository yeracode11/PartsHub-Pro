import '../../models/product_model.dart';

// Events
abstract class CartEvent {}

class CartLoadRequested extends CartEvent {}

class CartItemAdded extends CartEvent {
  final Product product;
  final int quantity;
  CartItemAdded({required this.product, this.quantity = 1});
}

class CartItemRemoved extends CartEvent {
  final int productId;
  CartItemRemoved({required this.productId});
}

class CartQuantityUpdated extends CartEvent {
  final int productId;
  final int quantity;
  CartQuantityUpdated({required this.productId, required this.quantity});
}

class CartCleared extends CartEvent {}
