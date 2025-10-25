import '../../models/vehicle_model.dart';

// States
abstract class VehicleState {}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  VehicleLoaded(this.vehicles);
}

class VehicleError extends VehicleState {
  final String message;
  VehicleError(this.message);
}
