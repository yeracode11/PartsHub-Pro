import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/config/app_config.dart';
import '../../data/models/user_entity.dart';
import '../../data/users_repository.dart';

part 'users_event.dart';
part 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  UsersBloc(this._repository) : super(const UsersState()) {
    on<UsersLoadRequested>(_onLoad);
    on<UsersSearchChanged>(_onSearchChanged);
    on<UserSaved>(_onSaved);
    on<UserDeleted>(_onDeleted);
  }

  final UsersRepository _repository;

  Future<void> _onLoad(UsersLoadRequested event, Emitter<UsersState> emit) async {
    emit(state.copyWith(listLoading: true, listError: null));
    try {
      final page = await _repository.fetchPage(
        page: event.page,
        pageSize: AppConfig.defaultPageSize,
        search: event.search,
      );
      emit(
        state.copyWith(
          listLoading: false,
          page: page,
          search: event.search ?? state.search,
          currentPage: event.page,
          clearMutationError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(listLoading: false, listError: e.toString()));
    }
  }

  Future<void> _onSearchChanged(UsersSearchChanged event, Emitter<UsersState> emit) async {
    add(UsersLoadRequested(page: 1, search: event.query));
  }

  Future<void> _onSaved(UserSaved event, Emitter<UsersState> emit) async {
    emit(state.copyWith(mutating: true));
    try {
      if (event.id != null) {
        await _repository.update(event.id!, event.body);
      } else {
        await _repository.create(event.body);
      }
      emit(state.copyWith(mutating: false));
      add(UsersLoadRequested(page: state.currentPage, search: state.search));
    } catch (e) {
      emit(state.copyWith(mutating: false, mutationError: e.toString()));
    }
  }

  Future<void> _onDeleted(UserDeleted event, Emitter<UsersState> emit) async {
    emit(state.copyWith(mutating: true));
    try {
      await _repository.delete(event.id);
      emit(state.copyWith(mutating: false));
      add(UsersLoadRequested(page: state.currentPage, search: state.search));
    } catch (e) {
      emit(state.copyWith(mutating: false, mutationError: e.toString()));
    }
  }
}
