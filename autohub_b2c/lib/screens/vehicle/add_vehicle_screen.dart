import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/vehicle/vehicle_bloc.dart';
import '../../blocs/vehicle/vehicle_event.dart';
import '../../blocs/vehicle/vehicle_state.dart';
import '../../core/design/app_spacing.dart';
import '../../models/vehicle_model.dart';

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController(text: '2020');
  final _plate = TextEditingController();
  final _mileage = TextEditingController(text: '0');
  final _vin = TextEditingController();
  final _customerId = TextEditingController(text: '1');
  FuelType _fuel = FuelType.petrol;
  TransmissionType _transmission = TransmissionType.automatic;
  bool _submitting = false;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _mileage.dispose();
    _vin.dispose();
    _customerId.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт сервера')),
      );
      return;
    }

    final customerId = int.tryParse(_customerId.text.trim());
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите ID клиента (customerId)')),
      );
      return;
    }

    setState(() => _submitting = true);
    final data = {
      'brand': _brand.text.trim(),
      'model': _model.text.trim(),
      'year': int.parse(_year.text),
      'plateNumber': _plate.text.trim(),
      if (_vin.text.trim().isNotEmpty) 'vin': _vin.text.trim(),
      'fuelType': _fuel.name,
      'transmission': _transmission.name,
      'currentMileage': int.tryParse(_mileage.text) ?? 0,
      'customerId': customerId,
    };

    context.read<VehicleBloc>().add(
          VehicleCreateRequested(data: data),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Добавить авто'),
      ),
      body: BlocListener<VehicleBloc, VehicleState>(
        listener: (context, state) {
          if (state is VehicleOperationSuccess) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Автомобиль сохранён на сервере')),
            );
          }
          if (state is VehicleError) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              TextFormField(
                controller: _brand,
                decoration: const InputDecoration(
                  labelText: 'Марка',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Укажите марку' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'Модель'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Укажите модель' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Год выпуска'),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Некорректный год' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _plate,
                decoration: const InputDecoration(labelText: 'Госномер'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Укажите госномер' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _mileage,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Пробег, км'),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _customerId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ID клиента (customerId)',
                  helperText: 'ID из CRM на сервере',
                ),
                validator: (v) =>
                    int.tryParse(v ?? '') == null ? 'Укажите customerId' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _vin,
                decoration:
                    const InputDecoration(labelText: 'VIN (необязательно)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<FuelType>(
                initialValue: _fuel,
                decoration: const InputDecoration(labelText: 'Топливо'),
                items: FuelType.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(_fuelLabel(f)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _fuel = v ?? FuelType.petrol),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<TransmissionType>(
                initialValue: _transmission,
                decoration: const InputDecoration(labelText: 'Коробка передач'),
                items: TransmissionType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(_transmissionLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(
                  () => _transmission = v ?? TransmissionType.automatic,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Сохранить на сервере'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fuelLabel(FuelType type) => switch (type) {
        FuelType.petrol => 'Бензин',
        FuelType.diesel => 'Дизель',
        FuelType.electric => 'Электро',
        FuelType.hybrid => 'Гибрид',
      };

  String _transmissionLabel(TransmissionType type) => switch (type) {
        TransmissionType.manual => 'МКПП',
        TransmissionType.automatic => 'АКПП',
        TransmissionType.robot => 'Робот',
        TransmissionType.cvt => 'Вариатор',
      };
}
