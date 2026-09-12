import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/cart_model.dart';
import 'cart_event.dart';
import 'cart_state.dart';

// BLoC
class CartBloc extends Bloc<CartEvent, CartState> {
  static const String _storageKey = 'cart_data';

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
      // Загружаем корзину из локального хранилища
      final cart = await _loadCartFromStorage();
      
      if (!isClosed) emit(CartLoaded(cart: cart));
    } catch (e) {
      // Если ошибка, создаем пустую корзину
      final cart = Cart(
        items: [],
        lastUpdated: DateTime.now(),
      );
      
      if (!isClosed) emit(CartLoaded(cart: cart));
    }
  }
  
  Future<Cart> _loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString(_storageKey);
      
      if (cartJson != null) {
        return Cart.fromJson(json.decode(cartJson));
      }
    } catch (e) {
      print('Ошибка загрузки корзины: $e');
    }
    
    // Возвращаем пустую корзину если ничего не найдено
    return Cart(
      items: [],
      lastUpdated: DateTime.now(),
    );
  }
  
  Future<void> _saveCartToStorage(Cart cart) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(cart.toJson());
      await prefs.setString(_storageKey, cartJson);
    } catch (e) {
      print('Ошибка сохранения корзины: $e');
    }
  }

  Future<Cart> _currentCart() async {
    if (state is CartLoaded) {
      return (state as CartLoaded).cart;
    }
    return _loadCartFromStorage();
  }

  void _onItemAdded(
    CartItemAdded event,
    Emitter<CartState> emit,
  ) async {
    final currentCart = await _currentCart();
    final newCart = currentCart.addItem(
      event.product,
      quantity: event.quantity,
    );

    await _saveCartToStorage(newCart);

    if (!isClosed) emit(CartLoaded(cart: newCart));
  }

  void _onItemRemoved(
    CartItemRemoved event,
    Emitter<CartState> emit,
  ) async {
    final currentCart = await _currentCart();
    final newCart = currentCart.removeItem(event.productId);

    await _saveCartToStorage(newCart);

    if (!isClosed) emit(CartLoaded(cart: newCart));
  }

  void _onQuantityUpdated(
    CartQuantityUpdated event,
    Emitter<CartState> emit,
  ) async {
    final currentCart = await _currentCart();
    final newCart = currentCart.updateQuantity(
      event.productId,
      event.quantity,
    );

    await _saveCartToStorage(newCart);

    if (!isClosed) emit(CartLoaded(cart: newCart));
  }

  void _onCleared(
    CartCleared event,
    Emitter<CartState> emit,
  ) async {
    final newCart = Cart(
      items: [],
      lastUpdated: DateTime.now(),
    );

    await _saveCartToStorage(newCart);

    if (!isClosed) emit(CartLoaded(cart: newCart));
  }
}
