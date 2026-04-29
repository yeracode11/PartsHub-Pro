part of 'auth_bloc.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final AdminUser user;

  @override
  List<Object?> get props => [user];
}

/// Logged in successfully but role is not superadmin (UI gate only).
class AuthAccessDenied extends AuthState {
  const AuthAccessDenied(this.user);

  final AdminUser user;

  @override
  List<Object?> get props => [user];
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
