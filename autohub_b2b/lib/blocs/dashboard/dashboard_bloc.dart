import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_event.dart';
import 'package:autohub_b2b/blocs/dashboard/dashboard_state.dart';
import 'package:autohub_b2b/services/api/dashboard_api_service.dart';
import 'package:autohub_b2b/models/dashboard_stats_model.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final DashboardApiService _apiService = DashboardApiService();

  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardLoadRequested>(_onLoadRequested);
    on<DashboardRefreshRequested>(_onRefreshRequested);
    on<DashboardChartPeriodChanged>(_onChartPeriodChanged);
  }

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      emit(DashboardLoading());

      // Загружаем все данные параллельно
      final results = await Future.wait([
        _apiService.getStats(),
        _apiService.getSalesChart(period: '7d'),
        _apiService.getRecentOrders(limit: 5),
        _apiService.getPopularItems(limit: 5),
      ]);

      final stats = results[0] as DashboardStats;
      final chartData = results[1] as SalesChartData;
      final recentOrders = results[2] as List;
      final popularItems = results[3] as List;

      emit(DashboardLoaded(
        stats: stats,
        chartData: chartData,
        recentOrders: recentOrders.cast(),
        popularItems: popularItems.cast(),
        currentPeriod: '7d',
      ));
    } catch (e) {
      emit(DashboardError('Ошибка загрузки данных: $e'));
    }
  }

  Future<void> _onRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      // Сохраняем текущее состояние
      final currentState = state;
      if (currentState is DashboardLoaded) {
        emit(DashboardRefreshing(currentState));
      }

      // Загружаем свежие данные
      final results = await Future.wait([
        _apiService.getStats(),
        _apiService.getSalesChart(
          period: currentState is DashboardLoaded
              ? currentState.currentPeriod
              : '7d',
        ),
        _apiService.getRecentOrders(limit: 5),
        _apiService.getPopularItems(limit: 5),
      ]);

      final stats = results[0] as DashboardStats;
      final chartData = results[1] as SalesChartData;
      final recentOrders = results[2] as List;
      final popularItems = results[3] as List;

      emit(DashboardLoaded(
        stats: stats,
        chartData: chartData,
        recentOrders: recentOrders.cast(),
        popularItems: popularItems.cast(),
        currentPeriod: currentState is DashboardLoaded
            ? currentState.currentPeriod
            : '7d',
      ));
    } catch (e) {
      emit(DashboardError('Ошибка обновления данных: $e'));
    }
  }

  Future<void> _onChartPeriodChanged(
    DashboardChartPeriodChanged event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      final currentState = state;
      if (currentState is! DashboardLoaded) return;

      // Загружаем данные графика для нового периода
      final chartData = await _apiService.getSalesChart(period: event.period);

      emit(currentState.copyWith(
        chartData: chartData,
        currentPeriod: event.period,
      ));
    } catch (e) {
      // Не показываем ошибку, просто оставляем текущие данные
    }
  }
}

