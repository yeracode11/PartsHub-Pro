import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/cart/cart_event.dart';
import '../../blocs/cart/cart_state.dart';
import '../../core/constants/app_branding.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../models/product_model.dart';
import '../../services/api_client.dart';
import '../../services/orders_api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/cart_item_widget.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _address = TextEditingController(text: 'Алматы');
  bool _submitting = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _checkout(CartLoaded state) async {
    if (state.cart.items.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final api = OrdersApiService(ApiClient());
      final items = state.cart.items
          .map(
            (i) => OrderItem(
              id: 0,
              productId: i.product.id,
              productName: i.product.name,
              productImage: i.product.images.isNotEmpty
                  ? i.product.images.first
                  : '',
              price: i.product.price,
              quantity: i.quantity,
              total: i.product.price * i.quantity,
            ),
          )
          .toList();

      await api.createOrder(
        items: items,
        shippingAddress: _address.text.trim(),
        notes: 'Заказ из приложения ${AppBranding.appName}',
      );

      if (!mounted) return;
      context.read<CartBloc>().add(CartCleared());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ оформлен')),
      );
      context.go('/orders');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Корзина'),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is CartLoading) return const LoadingView();
          if (state is! CartLoaded) return const SizedBox.shrink();

          if (state.cart.items.isEmpty) {
            return EmptyStateView(
              icon: Icons.shopping_cart_outlined,
              title: 'Корзина пуста',
              subtitle: 'Добавьте запчасти из каталога',
              actionLabel: 'В каталог',
              onAction: () => context.go('/parts'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  itemCount: state.cart.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = state.cart.items[index];
                    return CartItemWidget(
                      item: item,
                      onIncrement: () => context.read<CartBloc>().add(
                            CartQuantityUpdated(
                              productId: item.product.id,
                              quantity: item.quantity + 1,
                            ),
                          ),
                      onDecrement: () {
                        if (item.quantity <= 1) {
                          context.read<CartBloc>().add(
                                CartItemRemoved(productId: item.product.id),
                              );
                        } else {
                          context.read<CartBloc>().add(
                                CartQuantityUpdated(
                                  productId: item.product.id,
                                  quantity: item.quantity - 1,
                                ),
                              );
                        }
                      },
                      onRemove: () => context.read<CartBloc>().add(
                            CartItemRemoved(productId: item.product.id),
                          ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Адрес доставки',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Итого: ${Formatters.price(state.cart.totalAmount)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () => _checkout(state),
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Оформить'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
