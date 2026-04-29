part of 'users_bloc.dart';

class UsersState extends Equatable {
  const UsersState({
    this.listLoading = false,
    this.listError,
    this.page,
    this.search = '',
    this.currentPage = 1,
    this.mutating = false,
    this.mutationError,
  });

  final bool listLoading;
  final String? listError;
  final UsersPageResult? page;
  final String search;
  final int currentPage;
  final bool mutating;
  final String? mutationError;

  UsersState copyWith({
    bool? listLoading,
    String? listError,
    UsersPageResult? page,
    String? search,
    int? currentPage,
    bool? mutating,
    String? mutationError,
    bool clearMutationError = false,
    bool clearListError = false,
  }) {
    return UsersState(
      listLoading: listLoading ?? this.listLoading,
      listError: clearListError ? null : (listError ?? this.listError),
      page: page ?? this.page,
      search: search ?? this.search,
      currentPage: currentPage ?? this.currentPage,
      mutating: mutating ?? this.mutating,
      mutationError: clearMutationError ? null : (mutationError ?? this.mutationError),
    );
  }

  @override
  List<Object?> get props =>
      [listLoading, listError, page, search, currentPage, mutating, mutationError];
}
