import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/vehicle/vehicle_bloc.dart';
import '../../blocs/vehicle/vehicle_event.dart';
import '../../blocs/vehicle/vehicle_state.dart';
import '../../core/design/app_spacing.dart';
import '../../models/vehicle_model.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/vehicle_card.dart';
import '../../widgets/vehicle_photo.dart';

class VehicleDetailScreen extends StatelessWidget {
  final int vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Карточка авто'),
      ),
      body: BlocBuilder<VehicleBloc, VehicleState>(
        builder: (context, state) {
          if (state is! VehicleLoaded) return const LoadingView();
          Vehicle? vehicle;
          for (final v in state.vehicles) {
            if (v.id == vehicleId) {
              vehicle = v;
              break;
            }
          }
          if (vehicle == null) {
            return const ErrorView(message: 'Автомобиль не найден');
          }

          final v = vehicle;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              VehiclePhotoHero(vehicle: v, height: 200),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: [
                    HealthScoreRing(score: v.healthScore, size: 100),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          StatusBadge(
                            label: v.healthLabel,
                            color: v.healthColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Section(
                title: 'Основное',
                children: [
                  _Info('Госномер', v.plateNumber),
                  _Info('Пробег', Formatters.mileage(v.currentMileage)),
                  _Info('Топливо', v.fuelTypeDisplay),
                  _Info('КПП', v.transmissionDisplay),
                  if (v.vin != null) _Info('VIN', v.vin!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Обслуживание',
                children: [
                  _Info('Статус ТО', v.serviceStatus),
                  if (v.lastServiceDate != null)
                    _Info(
                      'Последнее ТО',
                      Formatters.date(v.lastServiceDate!),
                    ),
                  if (v.nextServiceDate != null)
                    _Info(
                      'Следующее ТО',
                      Formatters.date(v.nextServiceDate!),
                    ),
                  if (v.nextServiceMileage != null)
                    _Info(
                      'ТО при пробеге',
                      Formatters.mileage(v.nextServiceMileage!),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: () => _updateMileage(context, v),
                icon: const Icon(Icons.speed_rounded),
                label: const Text('Обновить пробег'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => context.go('/services'),
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('Записаться на сервис'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateMileage(BuildContext context, Vehicle vehicle) async {
    final controller =
        TextEditingController(text: vehicle.currentMileage.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Обновить пробег'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Текущий пробег, км',
            suffixText: 'км',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null) Navigator.pop(ctx, value);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    context.read<VehicleBloc>().add(
          VehicleMileageUpdated(vehicleId: vehicle.id, mileage: result),
        );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(child: Column(children: children)),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;

  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
