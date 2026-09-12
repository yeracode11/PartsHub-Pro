import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../blocs/vehicle/vehicle_bloc.dart';
import '../../blocs/vehicle/vehicle_state.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_spacing.dart';
import '../../models/service_model.dart';
import '../../services/api_client.dart';
import '../../services/services_api_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_ui.dart';

class BookAppointmentScreen extends StatefulWidget {
  final AutoService service;

  const BookAppointmentScreen({super.key, required this.service});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedService;
  String? _selectedSlot;
  List<String> _slots = [];
  bool _loadingSlots = false;
  bool _submitting = false;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedService = widget.service.services.isNotEmpty
        ? widget.service.services.first
        : null;
    _selectedDay = DateTime.now().add(const Duration(days: 1));
    _loadSlots();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    if (_selectedDay == null) return;
    setState(() => _loadingSlots = true);
    try {
      final api = ServicesApiService(ApiClient());
      _slots = await api.getAvailableTimeSlots(
        widget.service.id,
        _selectedDay!,
      );
      _selectedSlot = _slots.isNotEmpty ? _slots.first : null;
    } catch (_) {
      _slots = ['09:00', '10:00', '11:00', '14:00', '15:00', '16:00'];
      _selectedSlot = _slots.first;
    }
    if (mounted) setState(() => _loadingSlots = false);
  }

  Future<void> _submit() async {
    if (_selectedDay == null ||
        _selectedService == null ||
        _selectedSlot == null) {
      return;
    }

    final vehicleState = context.read<VehicleBloc>().state;
    final vehicleId = vehicleState is VehicleLoaded && vehicleState.selected != null
        ? vehicleState.selected!.id.toString()
        : '1';

    setState(() => _submitting = true);
    try {
      final api = ServicesApiService(ApiClient());
      final price = widget.service.servicePrices[_selectedService!] ?? 0;
      await api.createAppointment(
        serviceId: widget.service.id,
        vehicleId: vehicleId,
        serviceName: _selectedService!,
        appointmentDate: _selectedDay!,
        timeSlot: _selectedSlot!,
        notes: _notes.text.trim(),
        estimatedPrice: price,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись создана')),
      );
      context.go('/orders');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _selectedService != null
        ? widget.service.servicePrices[_selectedService!]
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Запись на сервис'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ElevatedButton(
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
                : Text(
                    price != null
                        ? 'Подтвердить · ${Formatters.price(price)}'
                        : 'Подтвердить запись',
                  ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Text(widget.service.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xl),
          Text('Услуга', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _selectedService,
            items: widget.service.services
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedService = v),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Дата', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 60)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                _loadSlots();
              },
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Время', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (_loadingSlots)
            const Center(child: CircularProgressIndicator())
          else if (_slots.isEmpty)
            const Text('Нет свободных слотов на выбранную дату')
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _slots.map((slot) {
                final selected = slot == _selectedSlot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedSlot = slot),
                  selectedColor: AppColors.accentSoft,
                );
              }).toList(),
            ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Комментарий (необязательно)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
