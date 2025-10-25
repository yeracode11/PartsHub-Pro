import '../../models/service_model.dart';

// States
abstract class ServicesState {}

class ServicesInitial extends ServicesState {}

class ServicesLoading extends ServicesState {}

class ServicesLoaded extends ServicesState {
  final List<AutoService> services;
  ServicesLoaded(this.services);
}

class ServicesError extends ServicesState {
  final String message;
  ServicesError(this.message);
}
