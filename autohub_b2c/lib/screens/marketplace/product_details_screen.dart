import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/cart/cart_event.dart';
import '../../blocs/cart/cart_state.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../models/product_model.dart';
import '../../services/api_client.dart';
import '../../services/marketplace_api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product? product;
  final int productId;

  const ProductDetailsScreen({
    super.key,
    this.product,
    required this.productId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Product? _product;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    if (_product == null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = MarketplaceApiService(ApiClient());
      _product = await api.getProduct(widget.productId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }
    final product = _product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ErrorView(message: 'Товар не найден'),
      );
    }

    final imageUrl = product.images.isNotEmpty
        ? ApiClient.getImageUrl(product.images.first, width: 800, height: 800)
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Товар'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formatters.price(product.price),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      product.isInStock ? 'В наличии' : 'Нет в наличии',
                      style: TextStyle(
                        color: product.isInStock
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<CartBloc, CartState>(
                  builder: (context, state) {
                    final quantity = state is CartLoaded
                        ? state.cart.quantityOf(product.id)
                        : 0;

                    if (!product.isInStock) {
                      return ElevatedButton(
                        onPressed: null,
                        child: const Text('Нет в наличии'),
                      );
                    }

                    if (quantity == 0) {
                      return ElevatedButton.icon(
                        onPressed: () {
                          context.read<CartBloc>().add(
                                CartItemAdded(product: product),
                              );
                        },
                        icon: const Icon(Icons.add_shopping_cart_rounded),
                        label: const Text('В корзину'),
                      );
                    }

                    return Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (quantity <= 1) {
                                context.read<CartBloc>().add(
                                      CartItemRemoved(productId: product.id),
                                    );
                              } else {
                                context.read<CartBloc>().add(
                                      CartQuantityUpdated(
                                        productId: product.id,
                                        quantity: quantity - 1,
                                      ),
                                    );
                              }
                            },
                            icon: const Icon(Icons.remove_rounded,
                                color: Colors.white),
                          ),
                          Text(
                            '$quantity',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.read<CartBloc>().add(
                                    CartQuantityUpdated(
                                      productId: product.id,
                                      quantity: quantity + 1,
                                    ),
                                  );
                            },
                            icon: const Icon(Icons.add_rounded,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: AspectRatio(
              aspectRatio: 1.2,
              child: imageUrl != null
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceElevated,
                      child: const Icon(Icons.settings_suggest_rounded, size: 64),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              StatusBadge(label: product.brand, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(label: product.category, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoRow(label: 'SKU', value: product.sku),
          _InfoRow(label: 'Состояние', value: product.condition),
          _InfoRow(label: 'Продавец', value: product.sellerName ?? '—'),
          const SizedBox(height: AppSpacing.lg),
          Text('Описание', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(product.description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}
