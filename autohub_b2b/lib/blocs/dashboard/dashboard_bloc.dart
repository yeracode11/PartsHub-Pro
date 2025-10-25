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
      print('📊 DashboardBloc: Loading data...');
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

      print('✅ DashboardBloc: Data loaded successfully');
      print('   Stats: Revenue=${stats.totalRevenue}, Items=${stats.inventoryCount}');
      print('   Chart: ${chartData.data.length} points');
      print('   Orders: ${recentOrders.length} recent');
      print('   Popular: ${popularItems.length} items');

      emit(DashboardLoaded(
        stats: stats,
        chartData: chartData,
        recentOrders: recentOrders.cast(),
        popularItems: popularItems.cast(),
        currentPeriod: '7d',
      ));
    } catch (e) {
      print('❌ DashboardBloc: Error loading data - $e');
      emit(DashboardError('Ошибка загрузки данных: $e'));
    }
  }

  Future<void> _onRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    try {
      print('🔄 DashboardBloc: Refreshing data...');
      
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

      print('✅ DashboardBloc: Data refreshed');

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
      print('❌ DashboardBloc: Error refreshing data - $e');
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

      print('📈 DashboardBloc: Changing chart period to ${event.period}');

      // Загружаем данные графика для нового периода
      final chartData = await _apiService.getSalesChart(period: event.period);

      emit(currentState.copyWith(
        chartData: chartData,
        currentPeriod: event.period,
      ));

      print('✅ DashboardBloc: Chart period changed, ${chartData.data.length} points');
    } catch (e) {
      print('❌ DashboardBloc: Error changing chart period - $e');
      // Не показываем ошибку, просто оставляем текущие данные
    }
  }
}

