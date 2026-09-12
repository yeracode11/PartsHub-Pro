import 'package:flutter/material.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_spacing.dart';
import '../models/vehicle_model.dart';
import '../utils/formatters.dart';
import 'app_ui.dart';
import 'vehicle_photo.dart';

class HealthScoreRing extends StatelessWidget {
  final int score;
  final double size;

  const HealthScoreRing({super.key, required this.score, this.size = 72});

  Color get _color {
    if (score >= 75) return AppColors.healthGood;
    if (score >= 50) return AppColors.healthMid;
    return AppColors.healthBad;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: AppColors.surfaceMuted,
            color: _color,
            strokeCap: StrokeCap.round,
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: size * 0.26,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback? onTap;

  const VehicleCard({
    super.key,
    required this.vehicle,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          VehiclePhotoThumb(vehicle: vehicle),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle.fullName, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${vehicle.plateNumber} · ${Formatters.mileage(vehicle.currentMileage)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusBadge(label: '${vehicle.healthScore}', color: vehicle.healthColor),
        ],
      ),
    );
  }
}
