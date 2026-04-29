import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/transaction_entity.dart';
import '../../data/transactions_api.dart';

part 'transactions_event.dart';
part 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  TransactionsBloc(this._api) : super(const TransactionsState()) {
    on<TransactionsRequested>(_onLoad);
  }

  final TransactionsApi _api;

  Future<void> _onLoad(TransactionsRequested event, Emitter<TransactionsState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _api.listTransactions(
        from: event.from,
        to: event.to,
        userId: event.userId,
      );
      emit(
        state.copyWith(
          loading: false,
          items: items,
          from: event.from,
          to: event.to,
          userFilter: event.userId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
