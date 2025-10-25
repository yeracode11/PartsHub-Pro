import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/service_model.dart';
import '../../services/services_api_service.dart';
import 'services_event.dart';
import 'services_state.dart';

// BLoC
class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  final ServicesApiService _apiService;

  ServicesBloc({required ServicesApiService apiService}) 
      : _apiService = apiService,
        super(ServicesInitial()) {
    on<ServicesLoadRequested>(_onLoadRequested);
  }

  void _onLoadRequested(
    ServicesLoadRequested event,
    Emitter<ServicesState> emit,
  ) async {
    if (!isClosed) emit(ServicesLoading());
    
    try {
      final services = await _apiService.getServices();
      if (!isClosed) emit(ServicesLoaded(services));
    } catch (e) {
      if (!isClosed) emit(ServicesError('Ошибка загрузки сервисов: $e'));
    }
  }
}
