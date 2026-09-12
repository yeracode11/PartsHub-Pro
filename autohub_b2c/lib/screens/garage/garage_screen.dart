import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/vehicle/vehicle_bloc.dart';
import '../../blocs/vehicle/vehicle_event.dart';
import '../../blocs/vehicle/vehicle_state.dart';
import '../../core/constants/part_categories.dart';
import '../../core/navigation/garage_navigation.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../core/platform/platform_ui.dart';
import '../../models/product_model.dart';
import '../../models/service_model.dart';
import '../../services/api_client.dart';
import '../../services/marketplace_api_service.dart';
import '../../services/services_api_service.dart';
import '../../widgets/app_side_drawer.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/category_circle_grid.dart';
import '../../widgets/product_card.dart';
import '../../widgets/service_carousel.dart';
import '../../widgets/vehicle_dashboard.dart';
import '../../widgets/vehicle_photo.dart';

/// Главная: myAuto dashboard → категории → сервисы → запчасти.
class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  List<AutoService> _services = [];
  List<Product> _products = [];
  bool _loadingFeed = true;

  @override
  void initState() {
    super.initState();
    context.read<VehicleBloc>().add(VehicleLoadRequested());
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _carVisibility() {
    if (!_scrollController.hasClients) return 1;
    return VehicleHeroScrollReveal.visibilityFromScrollOffset(
      _scrollController.offset,
    );
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    try {
      final servicesApi = ServicesApiService(ApiClient());
      final marketApi = MarketplaceApiService(ApiClient());
      final results = await Future.wait([
        servicesApi.getServices(),
        marketApi.getPopularProducts(limit: 6),
      ]);
      var products = results[1] as List<Product>;
      if (products.isEmpty) {
        products = await marketApi.getProducts(limit: 6);
      }
      if (!mounted) return;
      setState(() {
        _services = results[0] as List<AutoService>;
        _products = products;
        _loadingFeed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  Future<void> _refresh() async {
    context.read<VehicleBloc>().add(VehicleLoadRequested());
    await _loadFeed();
  }

  void _openParts({String? category}) {
    if (category == null) {
      navigateFromGarage(context, '/parts');
    } else {
      navigateFromGarage(
        context,
        '/parts?category=${Uri.encodeComponent(category)}',
      );
    }
  }

  void _openService(AutoService service) {
    context.push('/service/${service.id}', extra: service);
  }

  void _toggleDrawer() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold == null) return;
    if (scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
    } else {
      scaffold.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = PlatformUI.bottomContentInset(context);

    return BlocBuilder<VehicleBloc, VehicleState>(
      builder: (context, vehicleState) {
        final hasVehicle =
            vehicleState is VehicleLoaded && vehicleState.selected != null;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: hasVehicle
              ? VehicleDashboardHeader(
                  menuIsOpen: _drawerOpen,
                  onMenuTap: _toggleDrawer,
                  onNotificationsTap: () => navigateFromGarage(context, '/orders'),
                )
              : null,
          drawer: hasVehicle ? const AppSideDrawer() : null,
          onDrawerChanged: (isOpen) {
            if (_drawerOpen != isOpen) {
              setState(() => _drawerOpen = isOpen);
            }
          },
          body: SafeArea(
            bottom: false,
            top: !hasVehicle,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                controller: _scrollController,
                clipBehavior: Clip.none,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _scrollController,
                      builder: (context, _) {
                        return BlocBuilder<VehicleBloc, VehicleState>(
                          builder: (context, state) {
                            if (state is VehicleLoaded &&
                                state.selected != null) {
                              final vehicle = state.selected!;
                              return VehicleDashboard(
                                vehicle: vehicle,
                                carVisibility: _carVisibility(),
                                menuIsOpen: _drawerOpen,
                                showHeader: false,
                                onVehicleTap: () =>
                                    context.push('/vehicle/${vehicle.id}'),
                                onMenuTap: _toggleDrawer,
                                onNotificationsTap: () =>
                                    navigateFromGarage(context, '/orders'),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                    BlocBuilder<VehicleBloc, VehicleState>(
                      builder: (context, state) {
                        if (state is VehicleLoaded && state.selected != null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: _NoVehicleState(
                            onAdd: () => context.push('/add-vehicle'),
                            onSearch: () => _openParts(),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          _HomeSearchBar(onTap: () => _openParts()),
                          const SizedBox(height: AppSpacing.xxxl),
                          SectionLabel(
                            title: 'Категории',
                            action: 'Все',
                            actionWithChevron: true,
                            onAction: () => _openParts(),
                          ),
                          CategoryCircleGrid(
                            crossAxisCount: 4,
                            categories: PartCategories.featured,
                            onCategoryTap: (c) => _openParts(category: c.name),
                          ),
                          const SizedBox(height: AppSpacing.xxxl),
                          SectionLabel(
                            title: 'Автосервисы',
                            action: 'Все',
                            actionWithChevron: true,
                            onAction: () => navigateFromGarage(context, '/services'),
                          ),
                          if (_loadingFeed)
                            const SizedBox(
                              height: 268,
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            ServiceCarousel(
                              services: _services,
                              onServiceTap: _openService,
                            ),
                          const SizedBox(height: AppSpacing.xxxl),
                          SectionLabel(
                            title: 'Популярные запчасти',
                            action: 'Все',
                            actionWithChevron: true,
                            onAction: () => _openParts(),
                          ),
                          if (_loadingFeed)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.huge,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else if (_products.isEmpty)
                            const _FeedEmptyHint(
                              icon: Icons.shopping_bag_outlined,
                              message: 'Запчасти пока не загружены',
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _products.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppSpacing.md,
                                crossAxisSpacing: AppSpacing.md,
                                childAspectRatio: 0.62,
                              ),
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return ProductCard(
                                  product: product,
                                  onTap: () => context.push(
                                    '/product/${product.id}',
                                    extra: product,
                                  ),
                                );
                              },
                            ),
                          SizedBox(height: bottomInset),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoVehicleState extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onSearch;

  const _NoVehicleState({
    required this.onAdd,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Добро пожаловать',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Добавьте автомобиль, чтобы видеть его на главной',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xxl),
        _AddVehiclePrompt(onTap: onAdd),
        const SizedBox(height: AppSpacing.lg),
        _HomeSearchBar(onTap: onSearch),
      ],
    );
  }
}

class _HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Поиск запчастей',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Какую запчасть ищете?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddVehiclePrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _AddVehiclePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Добавить автомобиль',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedEmptyHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _FeedEmptyHint({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
