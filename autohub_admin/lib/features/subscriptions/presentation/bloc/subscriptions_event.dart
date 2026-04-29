part of 'subscriptions_bloc.dart';

sealed class SubscriptionsEvent extends Equatable {
  const SubscriptionsEvent();

  @override
  List<Object?> get props => [];
}

class SubscriptionsRequested extends SubscriptionsEvent {
  const SubscriptionsRequested();
}

class SubscriptionPatchSubmitted extends SubscriptionsEvent {
  const SubscriptionPatchSubmitted({required this.id, required this.body});

  final String id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}
