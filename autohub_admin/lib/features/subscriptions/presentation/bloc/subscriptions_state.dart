part of 'subscriptions_bloc.dart';

class SubscriptionsState extends Equatable {
  const SubscriptionsState({
    this.loading = false,
    this.error,
    this.items = const [],
    this.mutating = false,
    this.mutationError,
  });

  final bool loading;
  final String? error;
  final List<SubscriptionEntity> items;
  final bool mutating;
  final String? mutationError;

  SubscriptionsState copyWith({
    bool? loading,
    String? error,
    List<SubscriptionEntity>? items,
    bool? mutating,
    String? mutationError,
    bool clearError = false,
  }) {
    return SubscriptionsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      mutating: mutating ?? this.mutating,
      mutationError: mutationError ?? this.mutationError,
    );
  }

  @override
  List<Object?> get props => [loading, error, items, mutating, mutationError];
}
