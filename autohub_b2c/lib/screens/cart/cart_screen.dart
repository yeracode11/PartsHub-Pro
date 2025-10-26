import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/cart_model.dart';
import '../../models/product_model.dart';
import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/cart/cart_event.dart';
import '../../blocs/cart/cart_state.dart';
import '../../widgets/cart_item_widget.dart';
import '../../services/orders_api_service.dart';
import '../../services/api_client.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CartBloc>().add(CartLoadRequested());
      }
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/'),
        ),
        actions: [
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state is CartLoaded && state.cart.isNotEmpty) {
                return TextButton(
                  onPressed: () {
                    _showClearCartDialog(context);
                  },
                  child: const Text(
                    'Очистить',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is CartLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is CartError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки корзины',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (state as CartError).message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<CartBloc>().add(CartLoadRequested());
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (state is CartLoaded) {
            final cart = (state as CartLoaded).cart;
            
            if (cart.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Корзина пуста',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Добавьте товары из маркетплейса',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/');
                      },
                      child: const Text('Перейти к покупкам'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Список товаров
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return CartItemWidget(
                        item: item,
                        onQuantityChanged: (quantity) {
                          context.read<CartBloc>().add(
                            CartQuantityUpdated(
                              productId: item.product.id,
                              quantity: quantity,
                            ),
                          );
                        },
                        onRemove: () {
                          context.read<CartBloc>().add(
                            CartItemRemoved(productId: item.product.id),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Итого и кнопка заказа
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Итого (${cart.totalItems} товаров):',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            cart.totalAmountFormatted,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            _showCheckoutDialog(context, cart);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Оформить заказ',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить корзину'),
        content: const Text('Вы уверены, что хотите удалить все товары из корзины?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<CartBloc>().add(CartCleared());
            },
            child: const Text(
              'Очистить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckoutDialog(BuildContext context, Cart cart) async {
    // Формируем OrderItem из корзины
    final orderItems = cart.items.map((cartItem) {
      return OrderItem(
        id: 0, // Будет присвоено на бэкенде
        productId: cartItem.product.id!,
        productName: cartItem.product.name,
        productImage: cartItem.product.images.isNotEmpty 
            ? cartItem.product.images.first 
            : '',
        price: cartItem.product.price,
        quantity: cartItem.quantity,
        total: cartItem.totalPrice,
      );
    }).toList();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Оформление заказа'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Товаров: ${cart.totalItems}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  'Сумма: ${cart.totalAmountFormatted}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Адрес доставки',
                    hintText: 'Введите адрес доставки',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  maxLines: 2,
                  enabled: !_isCreatingOrder,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий (необязательно)',
                    hintText: 'Дополнительные пожелания...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                  enabled: !_isCreatingOrder,
                ),
                if (_isCreatingOrder) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isCreatingOrder 
                  ? null 
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: _isCreatingOrder ? null : () async {
                if (_addressController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Введите адрес доставки'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() {
                  _isCreatingOrder = true;
                });

                try {
                  final ordersApiService = OrdersApiService(ApiClient());
                  final order = await ordersApiService.createOrder(
                    items: orderItems,
                    shippingAddress: _addressController.text.trim(),
                    notes: _notesController.text.trim().isEmpty 
                        ? null 
                        : _notesController.text.trim(),
                  );

                  if (!mounted) return;

                  // Очищаем корзину после создания заказа
                  context.read<CartBloc>().add(CartCleared());
                  
                  // Закрываем диалог
                  Navigator.of(dialogContext).pop();
                  
                  // Добавляем задержку для предотвращения ошибки навигации
                  await Future.delayed(const Duration(milliseconds: 300));
                  
                  if (!mounted) return;
                  
                  // Закрываем корзину
                  Navigator.of(context).pop();

                  // Показываем успешное сообщение
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Заказ ${order.orderNumber} успешно оформлен!'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: 'Посмотреть',
                          textColor: Colors.white,
                          onPressed: () {
                            context.go('/orders');
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка создания заказа: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  
                  setState(() {
                    _isCreatingOrder = false;
                  });
                }
              },
              child: const Text('Оформить заказ'),
            ),
          ],
        ),
      ),
    );
  }
}
