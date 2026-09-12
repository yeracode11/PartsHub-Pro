import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/cart/cart_bloc.dart';
import '../blocs/cart/cart_event.dart';
import '../blocs/cart/cart_state.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../models/product_model.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';
import 'app_ui.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final bool showCartActions;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.showCartActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final rawUrl = product.images.isNotEmpty ? product.images.first : '';
    final imageUrl =
        rawUrl.isNotEmpty ? ApiClient.getImageUrl(rawUrl) : null;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg - 1),
              ),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, __, ___) => _imagePlaceholder(),
                      placeholder: (_, __) => ColoredBox(
                        color: AppColors.surfaceElevated,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    )
                  : _imagePlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        Formatters.price(product.price),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                      ),
                    ),
                    if (showCartActions && product.isInStock)
                      _ProductCartControl(product: product),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return ColoredBox(
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textTertiary,
          size: 40,
        ),
      ),
    );
  }
}

class _ProductCartControl extends StatelessWidget {
  final Product product;

  const _ProductCartControl({required this.product});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        final quantity =
            state is CartLoaded ? state.cart.quantityOf(product.id) : 0;

        if (quantity == 0) {
          return _CartIconButton(
            icon: Icons.add_rounded,
            filled: true,
            onTap: () {
              context.read<CartBloc>().add(CartItemAdded(product: product));
            },
          );
        }

        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CartIconButton(
                icon: Icons.remove_rounded,
                onTap: () {
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  '$quantity',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _CartIconButton(
                icon: Icons.add_rounded,
                onTap: () {
                  context.read<CartBloc>().add(
                        CartQuantityUpdated(
                          productId: product.id,
                          quantity: quantity + 1,
                        ),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CartIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _CartIconButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Ink(
          width: filled ? 36 : 32,
          height: filled ? 36 : 32,
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
