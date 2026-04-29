part of 'transactions_bloc.dart';

sealed class TransactionsEvent extends Equatable {
  const TransactionsEvent();

  @override
  List<Object?> get props => [];
}

class TransactionsRequested extends TransactionsEvent {
  const TransactionsRequested({this.from, this.to, this.userId});

  final DateTime? from;
  final DateTime? to;
  final String? userId;

  @override
  List<Object?> get props => [from, to, userId];
}
