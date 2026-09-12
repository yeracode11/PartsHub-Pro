import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_effects.dart';
import '../core/design/app_spacing.dart';
import '../models/service_model.dart';
import '../utils/formatters.dart';
import 'service_card.dart';

/// Компактная карточка автосервиса для горизонтальной карусели на главной.
class ServiceCarouselCard extends StatelessWidget {
  final AutoService service;
  final VoidCallback? onTap;

  const ServiceCarouselCard({
    super.key,
    required this.service,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final minPrice = serviceMinPrice(service);

    return Semantics(
      button: onTap != null,
      label: service.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Ink(
            width: 272,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppEffects.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceCoverHeader(service: service, height: 112),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ServiceAddressRow(address: service.address),
                      if (minPrice != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'от ${Formatters.price(minPrice)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Горизонтальная карусель автосервисов.
class ServiceCarousel extends StatelessWidget {
  final List<AutoService> services;
  final ValueChanged<AutoService>? onServiceTap;

  const ServiceCarousel({
    super.key,
    required this.services,
    this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const _SectionPlaceholder(
        icon: Icons.build_outlined,
        message: 'Автосервисы скоро появятся',
      );
    }

    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final service = services[index];
          return ServiceCarouselCard(
            service: service,
            onTap: onServiceTap == null
                ? null
                : () => onServiceTap!(service),
          );
        },
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SectionPlaceholder({
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
