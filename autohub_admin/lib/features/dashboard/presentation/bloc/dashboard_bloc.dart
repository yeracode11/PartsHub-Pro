import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/dashboard_repository.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this._repository) : super(const DashboardInitial()) {
    on<DashboardRequested>(_onRequested);
  }

  final DashboardRepository _repository;

  Future<void> _onRequested(DashboardRequested event, Emitter<DashboardState> emit) async {
    emit(const DashboardLoading());
    try {
      final snap = await _repository.loadOverview();
      emit(DashboardReady(snap));
    } catch (e) {
      emit(DashboardFailure(e.toString()));
    }
  }
}
