import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../models/service_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';

class ServiceDetailsScreen extends StatelessWidget {
  final AutoService service;

  const ServiceDetailsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(service.name),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
            onPressed: () => context.push(
              '/book-appointment/${service.id}',
              extra: service,
            ),
            child: const Text('Записаться на сервис'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('${service.rating} · ${service.reviewCount} отзывов'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _row(Icons.location_on_outlined, service.address),
                _row(Icons.phone_outlined, service.phone),
                if (service.workingHours.isNotEmpty)
                  _row(Icons.schedule_rounded, service.workingHours.join(', ')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Услуги', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          ...service.services.map((name) {
            final price = service.servicePrices[name];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(name)),
                    if (price != null)
                      Text(
                        Formatters.price(price),
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

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
