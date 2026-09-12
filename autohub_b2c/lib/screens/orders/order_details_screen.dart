import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../services/api_client.dart';
import '../../services/orders_api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  dynamic _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = OrdersApiService(ApiClient());
      _order = await api.getOrder(widget.orderId);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: LoadingView());
    }
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ErrorView(message: 'Заказ не найден'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(order.orderNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Статус', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                StatusBadge(label: order.status, color: AppColors.primary),
                const SizedBox(height: AppSpacing.lg),
                Text('Сумма', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  Formatters.price(order.totalAmount),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (order.shippingAddress != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Доставка', style: Theme.of(context).textTheme.bodySmall),
                  Text(order.shippingAddress!),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Состав заказа', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...order.items.map<Widget>((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName),
                          Text('${item.quantity} шт. · ${Formatters.price(item.price)}'),
                        ],
                      ),
                    ),
                    Text(
                      Formatters.price(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
