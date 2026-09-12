import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../models/product_model.dart';
import '../../models/service_model.dart';
import '../../services/api_client.dart';
import '../../services/orders_api_service.dart';
import '../../services/services_api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Order> _orders = [];
  List<ServiceAppointment> _appointments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ordersApi = OrdersApiService(ApiClient());
      final servicesApi = ServicesApiService(ApiClient());

      final ordersFuture = ordersApi.getUserOrders();
      final appointmentsFuture = servicesApi.getAppointments();

      _orders = await ordersFuture;
      try {
        _appointments = await appointmentsFuture;
      } catch (e) {
        _appointments = [];
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.md,
              ),
              child: const PageHeader(
                title: 'Заказы',
                subtitle: 'Запчасти и записи на сервис',
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Запчасти'),
                Tab(text: 'Сервис'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _error != null
                      ? ErrorView(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _OrdersList(
                              orders: _orders,
                              onRefresh: _load,
                            ),
                            _AppointmentsList(
                              appointments: _appointments,
                              onRefresh: _load,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  final Future<void> Function() onRefresh;

  const _OrdersList({required this.orders, required this.onRefresh});

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'processing':
      case 'shipped':
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает';
      case 'processing':
        return 'В обработке';
      case 'shipped':
        return 'Отправлен';
      case 'delivered':
        return 'Доставлен';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'Заказов пока нет',
        subtitle: 'Купите запчасти в каталоге',
        actionLabel: 'В каталог',
        onAction: () => context.go('/parts'),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final order = orders[index];
          return AppCard(
            onTap: () => context.push('/order/${order.id}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.orderNumber,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusBadge(
                      label: _statusLabel(order.status),
                      color: _statusColor(order.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${order.items.length} поз. · ${Formatters.price(order.totalAmount)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  Formatters.date(order.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  final List<ServiceAppointment> appointments;
  final Future<void> Function() onRefresh;

  const _AppointmentsList({
    required this.appointments,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_outlined,
        title: 'Записей нет',
        subtitle: 'Запишитесь на обслуживание в разделе Сервисы',
        actionLabel: 'К сервисам',
        onAction: () => context.go('/services'),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        itemCount: appointments.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final a = appointments[index];
          return AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.serviceName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${Formatters.date(a.appointmentDate)} · ${a.timeSlot}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                StatusBadge(
                  label: a.status,
                  color: AppColors.primary,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
