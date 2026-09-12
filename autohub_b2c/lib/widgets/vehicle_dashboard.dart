import 'package:flutter/material.dart';
import '../core/constants/app_branding.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_effects.dart';
import '../core/design/app_spacing.dart';
import '../models/vehicle_model.dart';
import '../utils/formatters.dart';
import 'vehicle_photo.dart';

/// Dashboard авто в стиле myAuto — header, hero-фото, bento-карточки.
class VehicleDashboard extends StatelessWidget {
  final Vehicle vehicle;
  final double carVisibility;
  final bool menuIsOpen;
  final bool showHeader;
  final VoidCallback? onVehicleTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationsTap;

  const VehicleDashboard({
    super.key,
    required this.vehicle,
    this.carVisibility = 1,
    this.menuIsOpen = false,
    this.showHeader = true,
    this.onVehicleTap,
    this.onMenuTap,
    this.onNotificationsTap,
  });

  static const _panelColor = AppColors.surface;
  static const _tileColor = AppColors.surfaceElevated;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            const SizedBox(height: AppSpacing.sm),
            VehicleDashboardHeader(
              menuIsOpen: menuIsOpen,
              onMenuTap: onMenuTap,
              onNotificationsTap: onNotificationsTap,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          GestureDetector(
            onTap: onVehicleTap,
            behavior: HitTestBehavior.opaque,
            child: VehiclePhotoHero(
              vehicle: vehicle,
              height: 196,
              studioBackground: true,
              visibility: carVisibility,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -AppSpacing.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(AppSpacing.radius2xl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _InfoTile(
                              color: _tileColor,
                              child: _VehicleInfoContent(vehicle: vehicle),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _InfoTile(
                              color: _tileColor,
                              child: _MaintenanceContent(vehicle: vehicle),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoTile(
                      color: _tileColor,
                      child: _HealthContent(vehicle: vehicle),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class VehicleDashboardHeader extends StatelessWidget
    implements PreferredSizeWidget {
  final bool menuIsOpen;
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationsTap;

  const VehicleDashboardHeader({
    super.key,
    this.menuIsOpen = false,
    this.onMenuTap,
    this.onNotificationsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                _CircleHeaderButton(
                  icon: menuIsOpen ? Icons.close_rounded : Icons.menu_rounded,
                  onTap: onMenuTap,
                  label: menuIsOpen ? 'Закрыть меню' : 'Меню',
                ),
                Expanded(
                  child: Text(
                    AppBranding.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                ),
                _CircleHeaderButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotificationsTap,
                  label: 'Уведомления',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  const _CircleHeaderButton({
    required this.icon,
    this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              boxShadow: AppEffects.softButtonShadow,
            ),
            child: Icon(icon, size: 22, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final Color color;
  final Widget child;

  const _InfoTile({
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _VehicleInfoContent extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleInfoContent({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textPrimary),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${vehicle.brand} ${vehicle.model}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          vehicle.plateNumber,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const Spacer(),
        Text(
          'Пробег',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.mileage(vehicle.currentMileage),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _MaintenanceContent extends StatelessWidget {
  final Vehicle vehicle;

  const _MaintenanceContent({required this.vehicle});

  String _formatDate(DateTime? date) {
    if (date == null) return '--.--.----';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d.$m.$y';
  }

  @override
  Widget build(BuildContext context) {
    final oilWarn = vehicle.needsService;
    final insuranceDate = vehicle.nextServiceDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 18, color: AppColors.textPrimary),
        const SizedBox(height: AppSpacing.md),
        _MaintenanceRow(
          icon: Icons.warning_amber_rounded,
          iconColor: oilWarn ? AppColors.warning : AppColors.textTertiary,
          label: 'Замена масла',
          trailing: _formatDate(
            oilWarn ? DateTime.now() : vehicle.lastServiceDate,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _MaintenanceRow(
          icon: Icons.schedule_rounded,
          label: 'Страховка',
          trailing: _formatDate(insuranceDate),
        ),
        const Spacer(),
      ],
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String trailing;

  const _MaintenanceRow({
    required this.icon,
    required this.label,
    required this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor ?? AppColors.textTertiary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          trailing,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _HealthContent extends StatelessWidget {
  final Vehicle vehicle;

  const _HealthContent({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final score = vehicle.healthScore;
    final color = AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_border_rounded,
                size: 18, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Техническое состояние',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '$score%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: AppColors.surfaceMuted,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
