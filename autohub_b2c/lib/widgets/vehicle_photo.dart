import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_assets.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../models/vehicle_model.dart';
import '../services/api_client.dart';

/// Прогресс видимости hero-фото при скролле главной (1 — полностью видно).
class VehicleHeroScrollReveal {
  static const fadeDistance = 170.0;

  static double visibilityFromScrollOffset(double offset) {
    return (1 - offset / fadeDistance).clamp(0.0, 1.0);
  }
}

/// Фото авто «в воздухе» с мягкой тенью — как на референсе myAuto.
class VehiclePhotoHero extends StatelessWidget {
  final Vehicle vehicle;
  final double height;
  final bool studioBackground;
  final double visibility;

  const VehiclePhotoHero({
    super.key,
    required this.vehicle,
    this.height = 168,
    this.studioBackground = false,
    this.visibility = 1,
  });

  @override
  Widget build(BuildContext context) {
    final rawUrl = vehicle.photoUrl;
    final imageUrl =
        rawUrl != null && rawUrl.isNotEmpty ? ApiClient.getImageUrl(rawUrl) : null;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageHeight = height * 0.88;

          final reveal = visibility.clamp(0.0, 1.0);
          final carLayer = Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                right: constraints.maxWidth * 0.04,
                bottom: height * 0.05,
                child: Container(
                  width: height * 1.12,
                  height: height * 0.1,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: constraints.maxWidth * 0.06,
                bottom: height * 0.09,
                child: Container(
                  width: height * 0.98,
                  height: height * 0.07,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: -constraints.maxWidth * 0.12,
                right: constraints.maxWidth * 0.04,
                bottom: height * 0.01,
                top: -height * 0.02,
                child: Align(
                  alignment: const Alignment(1.22, 0.52),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: imageHeight,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          errorWidget: (_, __, ___) => _DefaultVehicleImage(
                            height: imageHeight,
                          ),
                        )
                      : _DefaultVehicleImage(height: imageHeight),
                ),
              ),
            ],
          );

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (studioBackground)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.72, 0.35),
                        radius: 0.95,
                        colors: [
                          Color.lerp(
                            AppColors.surfaceMuted,
                            AppColors.background,
                            1 - reveal,
                          )!,
                          AppColors.background.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: reveal,
                child: Transform.translate(
                  offset: Offset(0, -28 * (1 - reveal)),
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * reveal,
                    alignment: const Alignment(0.72, 0.72),
                    child: carLayer,
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

class _DefaultVehicleImage extends StatelessWidget {
  final double height;

  const _DefaultVehicleImage({required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.vehicleHero,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
  }
}

/// Миниатюра для списка автомобилей.
class VehiclePhotoThumb extends StatelessWidget {
  final Vehicle vehicle;
  final double size;

  const VehiclePhotoThumb({
    super.key,
    required this.vehicle,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final rawUrl = vehicle.photoUrl;
    final imageUrl =
        rawUrl != null && rawUrl.isNotEmpty ? ApiClient.getImageUrl(rawUrl) : null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accentMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _thumbFallback(),
            )
          : _thumbFallback(),
    );
  }

  Widget _thumbFallback() {
    return Image.asset(
      AppAssets.vehicleHero,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
    );
  }
}
