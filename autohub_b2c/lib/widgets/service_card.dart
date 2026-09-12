import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_effects.dart';
import '../core/design/app_spacing.dart';
import '../models/service_model.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';

double? serviceMinPrice(AutoService service) {
  if (service.servicePrices.isEmpty) return null;
  return service.servicePrices.values.reduce((a, b) => a < b ? a : b);
}

/// Карточка автосервиса — выразительный layout с обложкой и CTA.
class ServiceCard extends StatelessWidget {
  final AutoService service;
  final VoidCallback? onTap;

  const ServiceCard({super.key, required this.service, this.onTap});

  @override
  Widget build(BuildContext context) {
    final minPrice = serviceMinPrice(service);

    return Semantics(
      button: onTap != null,
      label: service.name,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
              boxShadow: AppEffects.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceCoverHeader(service: service),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ServiceAddressRow(address: service.address),
                      if (service.services.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        ServiceTagsRow(services: service.services),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          if (minPrice != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'от ${Formatters.price(minPrice)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  Text(
                                    'за услугу',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            )
                          else
                            const Spacer(),
                          const ServiceBookChip(),
                        ],
                      ),
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

class ServiceCoverHeader extends StatelessWidget {
  final AutoService service;
  final double height;

  const ServiceCoverHeader({
    super.key,
    required this.service,
    this.height = 132,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = service.images.isNotEmpty
        ? ApiClient.getImageUrl(service.images.first)
        : null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusLg - 1),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _ServiceCoverFallback(),
              )
            else
              const _ServiceCoverFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.isVerified) const ServiceVerifiedBadge(),
                  const Spacer(),
                  ServiceRatingBadge(
                    rating: service.rating,
                    reviewCount: service.reviewCount,
                  ),
                ],
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.md,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.build_circle_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Автосервис',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                        ),
                      ],
                    ),
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

class ServiceRatingBadge extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const ServiceRatingBadge({
    super.key,
    required this.rating,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            ' · $reviewCount',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class ServiceVerifiedBadge extends StatelessWidget {
  const ServiceVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            'Проверен',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
          ),
        ],
      ),
    );
  }
}

class ServiceAddressRow extends StatelessWidget {
  final String address;

  const ServiceAddressRow({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty &&
        address.toLowerCase() != 'адрес не указан';

    return Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: hasAddress ? AppColors.primary : AppColors.textTertiary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            hasAddress ? address : 'Адрес не указан',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasAddress
                      ? AppColors.textSecondary
                      : AppColors.textTertiary,
                ),
          ),
        ),
      ],
    );
  }
}

class ServiceTagsRow extends StatelessWidget {
  final List<String> services;
  final int maxTags;

  const ServiceTagsRow({
    super.key,
    required this.services,
    this.maxTags = 3,
  });

  @override
  Widget build(BuildContext context) {
    final tags = services.take(maxTags).toList();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class ServiceBookChip extends StatelessWidget {
  const ServiceBookChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Записаться',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}

class _ServiceCoverFallback extends StatelessWidget {
  const _ServiceCoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accentMuted,
            AppColors.primary.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.car_repair_outlined,
          size: 48,
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}
