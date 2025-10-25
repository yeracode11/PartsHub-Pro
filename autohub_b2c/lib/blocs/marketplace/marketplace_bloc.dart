import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/product_model.dart';
import '../../services/marketplace_api_service.dart';
import '../../services/api_client.dart';
import 'marketplace_event.dart';
import 'marketplace_state.dart';

// BLoC
class MarketplaceBloc extends Bloc<MarketplaceEvent, MarketplaceState> {
  final MarketplaceApiService _apiService;

  MarketplaceBloc({MarketplaceApiService? apiService})
      : _apiService = apiService ?? MarketplaceApiService(ApiClient()),
        super(MarketplaceInitial()) {
    on<MarketplaceLoadRequested>(_onLoadRequested);
    on<MarketplaceSearchRequested>(_onSearchRequested);
    on<MarketplaceCategoryFilterRequested>(_onCategoryFilterRequested);
  }

  void _onLoadRequested(
    MarketplaceLoadRequested event,
    Emitter<MarketplaceState> emit,
  ) async {
    if (!isClosed) emit(MarketplaceLoading());

    try {
      print('🛒 MarketplaceBloc: Загружаем товары...');
      final products = await _apiService.getProducts();
      print('🛒 MarketplaceBloc: Загружено ${products.length} товаров');
      if (!isClosed) emit(MarketplaceLoaded(products));
    } catch (e) {
      print('❌ MarketplaceBloc: Ошибка загрузки товаров: $e');
      if (!isClosed) emit(MarketplaceError('Ошибка загрузки товаров: $e'));
    }
  }

  void _onSearchRequested(
    MarketplaceSearchRequested event,
    Emitter<MarketplaceState> emit,
  ) async {
    if (!isClosed) emit(MarketplaceLoading());

    try {
      final products = await _apiService.searchProducts(event.query);
      if (!isClosed) emit(MarketplaceLoaded(products));
    } catch (e) {
      if (!isClosed) emit(MarketplaceError('Ошибка поиска: $e'));
    }
  }

  void _onCategoryFilterRequested(
    MarketplaceCategoryFilterRequested event,
    Emitter<MarketplaceState> emit,
  ) async {
    if (!isClosed) emit(MarketplaceLoading());

    try {
      final products = await _apiService.getProductsByCategory(event.category);
      if (!isClosed) emit(MarketplaceLoaded(products));
    } catch (e) {
      if (!isClosed) emit(MarketplaceError('Ошибка фильтрации: $e'));
    }
  }

}
