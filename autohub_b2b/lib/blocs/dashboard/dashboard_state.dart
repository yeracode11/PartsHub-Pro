import 'package:equatable/equatable.dart';
import 'package:autohub_b2b/models/dashboard_stats_model.dart';
import 'package:autohub_b2b/models/order_model.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние
class DashboardInitial extends DashboardState {}

/// Загрузка данных
class DashboardLoading extends DashboardState {}

/// Данные загружены успешно
class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final SalesChartData chartData;
  final List<OrderModel> recentOrders;
  final List<PopularItem> popularItems;
  final String currentPeriod;

  const DashboardLoaded({
    required this.stats,
    required this.chartData,
    required this.recentOrders,
    required this.popularItems,
    this.currentPeriod = '7d',
  });

  /// Проверка на пустые данные
  bool get isEmpty =>
      stats.totalRevenue == 0 &&
      stats.monthlyRevenue == 0 &&
      stats.inventoryCount == 0 &&
      stats.activeOrdersCount == 0 &&
      chartData.data.isEmpty &&
      recentOrders.isEmpty &&
      popularItems.isEmpty;

  DashboardLoaded copyWith({
    DashboardStats? stats,
    SalesChartData? chartData,
    List<OrderModel>? recentOrders,
    List<PopularItem>? popularItems,
    String? currentPeriod,
  }) {
    return DashboardLoaded(
      stats: stats ?? this.stats,
      chartData: chartData ?? this.chartData,
      recentOrders: recentOrders ?? this.recentOrders,
      popularItems: popularItems ?? this.popularItems,
      currentPeriod: currentPeriod ?? this.currentPeriod,
    );
  }

  @override
  List<Object?> get props => [
        stats,
        chartData,
        recentOrders,
        popularItems,
        currentPeriod,
      ];
}

/// Ошибка загрузки
class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Обновление данных (сохраняя старые данные)
class DashboardRefreshing extends DashboardState {
  final DashboardLoaded previousState;

  const DashboardRefreshing(this.previousState);

  @override
  List<Object?> get props => [previousState];
}

