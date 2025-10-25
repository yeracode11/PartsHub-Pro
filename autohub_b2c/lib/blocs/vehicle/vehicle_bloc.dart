import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/vehicle_model.dart';
import 'vehicle_event.dart';
import 'vehicle_state.dart';

// BLoC
class VehicleBloc extends Bloc<VehicleEvent, VehicleState> {
  VehicleBloc() : super(VehicleInitial()) {
    on<VehicleLoadRequested>(_onLoadRequested);
  }

  void _onLoadRequested(
    VehicleLoadRequested event,
    Emitter<VehicleState> emit,
  ) async {
    if (!isClosed) emit(VehicleLoading());
    
    try {
      // TODO: Replace with real API call
      await Future.delayed(const Duration(seconds: 1));
      
      final vehicles = <Vehicle>[];
      if (!isClosed) emit(VehicleLoaded(vehicles));
    } catch (e) {
      if (!isClosed) emit(VehicleError('Ошибка загрузки автомобилей: $e'));
    }
  }
}
