part of 'users_bloc.dart';

sealed class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class UsersLoadRequested extends UsersEvent {
  const UsersLoadRequested({required this.page, this.search});

  final int page;
  final String? search;

  @override
  List<Object?> get props => [page, search];
}

class UsersSearchChanged extends UsersEvent {
  const UsersSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class UserSaved extends UsersEvent {
  const UserSaved({this.id, required this.body});

  final String? id;
  final Map<String, dynamic> body;

  @override
  List<Object?> get props => [id, body];
}

class UserDeleted extends UsersEvent {
  const UserDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
