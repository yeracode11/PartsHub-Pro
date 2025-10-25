import 'package:equatable/equatable.dart';

abstract class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки всех данных дашборда
class DashboardLoadRequested extends DashboardEvent {
  final String salesPeriod; // '7d', '30d', '90d'

  const DashboardLoadRequested({this.salesPeriod = '7d'});

  @override
  List<Object?> get props => [salesPeriod];
}

/// Событие обновления данных (pull-to-refresh)
class DashboardRefreshRequested extends DashboardEvent {}

/// Событие изменения периода графика
class DashboardChartPeriodChanged extends DashboardEvent {
  final String period; // '7d', '30d', '90d'

  const DashboardChartPeriodChanged(this.period);

  @override
  List<Object?> get props => [period];
}

