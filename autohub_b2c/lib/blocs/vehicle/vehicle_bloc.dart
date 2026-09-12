import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/vehicle_model.dart';
import '../../services/vehicles_api_service.dart';
import 'vehicle_event.dart';
import 'vehicle_state.dart';

class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  final VehiclesApiService _apiService;
  static const _selectedIdKey = 'b2c_selected_vehicle_id';

  VehicleBloc({required VehiclesApiService apiService})
      : _apiService = apiService,
        super(VehicleInitial()) {
    on<VehicleLoadRequested>(_onLoadRequested);
    on<VehicleSelected>(_onSelected);
    on<VehicleCreateRequested>(_onCreateRequested);
    on<VehicleMileageUpdated>(_onMileageUpdated);
  }

  Future<void> _onLoadRequested(
    VehicleLoadRequested event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    try {
      List<Vehicle> vehicles;
      if (event.customerId != null) {
        vehicles = await _apiService.getCustomerVehicles(event.customerId!);
      } else {
        vehicles = await _apiService.getUserVehicles();
      }

      final prefs = await SharedPreferences.getInstance();
      final selectedId = prefs.getInt(_selectedIdKey);
      Vehicle? selected;
      if (selectedId != null) {
        for (final v in vehicles) {
          if (v.id == selectedId) {
            selected = v;
            break;
          }
        }
      }
      selected ??= vehicles.isNotEmpty ? vehicles.first : null;
      if (selected != null) {
        await prefs.setInt(_selectedIdKey, selected.id);
      }

      emit(VehicleLoaded(vehicles: vehicles, selected: selected));
    } catch (e) {
      emit(VehicleError('Не удалось загрузить автомобили с сервера: $e'));
    }
  }

  Future<void> _onSelected(
    VehicleSelected event,
    Emitter<VehicleState> emit,
  ) async {
    if (state is! VehicleLoaded) return;
    final current = state as VehicleLoaded;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedIdKey, event.vehicle.id);
    emit(current.copyWith(selected: event.vehicle));
  }

  Future<void> _onCreateRequested(
    VehicleCreateRequested event,
    Emitter<VehicleState> emit,
  ) async {
    emit(VehicleLoading());
    try {
      final created = await _apiService.createVehicle(event.data);
      add(VehicleLoadRequested());
      emit(VehicleOperationSuccess(created));
    } catch (e) {
      emit(VehicleError('Не удалось создать автомобиль: $e'));
    }
  }

  Future<void> _onMileageUpdated(
    VehicleMileageUpdated event,
    Emitter<VehicleState> emit,
  ) async {
    if (state is! VehicleLoaded) return;
    final current = state as VehicleLoaded;
    try {
      final updated = await _apiService.updateMileage(
        event.vehicleId,
        event.mileage,
      );
      final vehicles = current.vehicles
          .map((v) => v.id == updated.id ? updated : v)
          .toList();
      final selected =
          current.selected?.id == updated.id ? updated : current.selected;
      emit(VehicleLoaded(vehicles: vehicles, selected: selected));
    } catch (e) {
      emit(VehicleError('Не удалось обновить пробег: $e'));
    }
  }
}
