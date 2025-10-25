import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/cart_model.dart';
import '../../models/product_model.dart';
import 'cart_event.dart';
import 'cart_state.dart';

// BLoC
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(CartInitial()) {
    on<CartLoadRequested>(_onLoadRequested);
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartQuantityUpdated>(_onQuantityUpdated);
    on<CartCleared>(_onCleared);
  }

  void _onLoadRequested(
    CartLoadRequested event,
    Emitter<CartState> emit,
  ) async {
    if (!isClosed) emit(CartLoading());
    
    try {
      // TODO: Load cart from local storage or API
      await Future.delayed(const Duration(milliseconds: 500));
      
      // For now, start with empty cart
      final cart = Cart(
        items: [],
        lastUpdated: DateTime.now(),
      );
      
      if (!isClosed) emit(CartLoaded(cart: cart));
    } catch (e) {
      if (!isClosed) emit(CartError(message: 'Ошибка загрузки корзины: $e'));
    }
  }

  void _onItemAdded(
    CartItemAdded event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;
      final newCart = currentState.cart.addItem(
        event.product,
        quantity: event.quantity,
      );
      
      if (!isClosed) emit(CartLoaded(cart: newCart));
    }
  }

  void _onItemRemoved(
    CartItemRemoved event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;
      final newCart = currentState.cart.removeItem(event.productId);
      
      if (!isClosed) emit(CartLoaded(cart: newCart));
    }
  }

  void _onQuantityUpdated(
    CartQuantityUpdated event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;
      final newCart = currentState.cart.updateQuantity(
        event.productId,
        event.quantity,
      );
      
      if (!isClosed) emit(CartLoaded(cart: newCart));
    }
  }

  void _onCleared(
    CartCleared event,
    Emitter<CartState> emit,
  ) async {
    if (state is CartLoaded) {
      final currentState = state as CartLoaded;
      final newCart = currentState.cart.clear();
      
      if (!isClosed) emit(CartLoaded(cart: newCart));
    }
  }
}
