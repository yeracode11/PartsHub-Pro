import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/models/subscription_entity.dart';
import '../../data/subscriptions_api.dart';

part 'subscriptions_event.dart';
part 'subscriptions_state.dart';

class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  SubscriptionsBloc(this._api) : super(const SubscriptionsState()) {
    on<SubscriptionsRequested>(_onLoad);
    on<SubscriptionPatchSubmitted>(_onPatch);
  }

  final SubscriptionsApi _api;

  Future<void> _onLoad(SubscriptionsRequested event, Emitter<SubscriptionsState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final items = await _api.listSubscriptions();
      emit(state.copyWith(loading: false, items: items));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _onPatch(SubscriptionPatchSubmitted event, Emitter<SubscriptionsState> emit) async {
    emit(state.copyWith(mutating: true, mutationError: null));
    try {
      await _api.patchSubscription(event.id, event.body);
      emit(state.copyWith(mutating: false));
      add(const SubscriptionsRequested());
    } catch (e) {
      emit(state.copyWith(mutating: false, mutationError: e.toString()));
    }
  }
}
