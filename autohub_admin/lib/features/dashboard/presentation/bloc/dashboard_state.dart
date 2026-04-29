part of 'dashboard_bloc.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardReady extends DashboardState {
  const DashboardReady(this.snapshot);

  final DashboardSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot];
}

class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
