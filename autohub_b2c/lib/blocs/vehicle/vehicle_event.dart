import '../../models/vehicle_model.dart';

abstract class VehicleEvent {}

class VehicleLoadRequested extends VehicleEvent {
  final int? customerId;
  VehicleLoadRequested({this.customerId});
}

class VehicleSelected extends VehicleEvent {
  final Vehicle vehicle;
  VehicleSelected(this.vehicle);
}

class VehicleCreateRequested extends VehicleEvent {
  final Map<String, dynamic> data;
  VehicleCreateRequested({required this.data});
}

class VehicleMileageUpdated extends VehicleEvent {
  final int vehicleId;
  final int mileage;
  VehicleMileageUpdated({required this.vehicleId, required this.mileage});
}
