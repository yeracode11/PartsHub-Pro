import '../../models/vehicle_model.dart';

abstract class VehicleState {}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  final Vehicle? selected;

  VehicleLoaded({required this.vehicles, this.selected});

  VehicleLoaded copyWith({List<Vehicle>? vehicles, Vehicle? selected}) {
    return VehicleLoaded(
      vehicles: vehicles ?? this.vehicles,
      selected: selected ?? this.selected,
    );
  }
}

class VehicleError extends VehicleState {
  final String message;
  VehicleError(this.message);
}

class VehicleOperationSuccess extends VehicleState {
  final Vehicle vehicle;
  VehicleOperationSuccess(this.vehicle);
}
