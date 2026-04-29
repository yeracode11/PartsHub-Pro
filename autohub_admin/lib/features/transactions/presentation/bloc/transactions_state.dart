part of 'transactions_bloc.dart';

class TransactionsState extends Equatable {
  const TransactionsState({
    this.loading = false,
    this.error,
    this.items = const [],
    this.from,
    this.to,
    this.userFilter,
  });

  final bool loading;
  final String? error;
  final List<TransactionEntity> items;
  final DateTime? from;
  final DateTime? to;
  final String? userFilter;

  TransactionsState copyWith({
    bool? loading,
    String? error,
    List<TransactionEntity>? items,
    DateTime? from,
    DateTime? to,
    String? userFilter,
    bool clearError = false,
  }) {
    return TransactionsState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      from: from ?? this.from,
      to: to ?? this.to,
      userFilter: userFilter ?? this.userFilter,
    );
  }

  @override
  List<Object?> get props => [loading, error, items, from, to, userFilter];
}
