import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/service_model.dart';
import '../../services/services_api_service.dart';
import 'services_event.dart';
import 'services_state.dart';

class ServicesBloc extends Bloc<ServicesEvent, ServicesState> {
  final ServicesApiService _apiService;
  List<AutoService> _all = [];

  ServicesBloc({required ServicesApiService apiService})
      : _apiService = apiService,
        super(ServicesInitial()) {
    on<ServicesLoadRequested>(_onLoadRequested);
    on<ServicesSearchRequested>(_onSearchRequested);
  }

  Future<void> _onLoadRequested(
    ServicesLoadRequested event,
    Emitter<ServicesState> emit,
  ) async {
    emit(ServicesLoading());
    try {
      final services = await _apiService.getServices();
      _all = services;
      emit(ServicesLoaded(services));
    } catch (e) {
      emit(ServicesError('Ошибка загрузки сервисов: $e'));
    }
  }

  Future<void> _onSearchRequested(
    ServicesSearchRequested event,
    Emitter<ServicesState> emit,
  ) async {
    if (_all.isEmpty) {
      add(ServicesLoadRequested());
      return;
    }
    final q = event.query.toLowerCase().trim();
    if (q.isEmpty) {
      emit(ServicesLoaded(List.from(_all)));
      return;
    }
    final filtered = _all.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.address.toLowerCase().contains(q) ||
          s.services.any((svc) => svc.toLowerCase().contains(q));
    }).toList();
    emit(ServicesLoaded(filtered));
  }
}
