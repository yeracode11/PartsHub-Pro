import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/cart/cart_bloc.dart';
import '../../blocs/cart/cart_state.dart';
import '../../blocs/marketplace/marketplace_bloc.dart';
import '../../blocs/marketplace/marketplace_event.dart';
import '../../blocs/marketplace/marketplace_state.dart';
import '../../core/constants/part_categories.dart';
import '../../core/design/app_spacing.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/product_card.dart';

class MarketplaceScreen extends StatefulWidget {
  final String? initialCategory;

  const MarketplaceScreen({super.key, this.initialCategory});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _search = TextEditingController();
  String? _category;

  static List<String> get _categories => PartCategories.marketplaceFilters;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategory;
    if (initial != null && initial.isNotEmpty && initial != 'Все') {
      _category = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<MarketplaceBloc>().add(
              MarketplaceCategoryFilterRequested(initial),
            );
      });
    } else {
      context.read<MarketplaceBloc>().add(MarketplaceLoadRequested());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      context.read<MarketplaceBloc>().add(MarketplaceLoadRequested());
    } else {
      context.read<MarketplaceBloc>().add(MarketplaceSearchRequested(query));
    }
  }

  void _filterCategory(String category) {
    setState(() => _category = category == 'Все' ? null : category);
    if (_category == null) {
      context.read<MarketplaceBloc>().add(MarketplaceLoadRequested());
    } else {
      context.read<MarketplaceBloc>().add(
            MarketplaceCategoryFilterRequested(_category!),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0,
              ),
              child: PageHeader(
                title: 'Запчасти',
                subtitle: 'Найдите нужную деталь',
                trailing: BlocBuilder<CartBloc, CartState>(
                  builder: (context, state) {
                    final count =
                        state is CartLoaded ? state.cart.totalItems : 0;
                    return IconActionButton(
                      icon: Icons.shopping_cart_outlined,
                      badgeCount: count,
                      onPressed: () => context.push('/cart'),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: AppSearchField(
                controller: _search,
                hint: 'Название или артикул',
                onChanged: _searchProducts,
                onClear: () {
                  _search.clear();
                  _searchProducts('');
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final selected =
                      (cat == 'Все' && _category == null) || cat == _category;
                  return CategoryChip(
                    label: cat,
                    selected: selected,
                    onTap: () => _filterCategory(cat),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: BlocBuilder<MarketplaceBloc, MarketplaceState>(
                builder: (context, state) {
                  if (state is MarketplaceLoading) {
                    return const LoadingView(message: 'Загрузка каталога...');
                  }
                  if (state is MarketplaceError) {
                    return ErrorView(
                      message: state.message,
                      onRetry: () => context
                          .read<MarketplaceBloc>()
                          .add(MarketplaceLoadRequested()),
                    );
                  }
                  if (state is MarketplaceLoaded) {
                    final products = [...state.products]
                      ..sort((a, b) => a.price.compareTo(b.price));
                    if (products.isEmpty) {
                      return const EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'Ничего не найдено',
                        subtitle: 'Попробуйте другой запрос или категорию',
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductCard(
                          product: product,
                          onTap: () => context.push(
                            '/product/${product.id}',
                            extra: product,
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
