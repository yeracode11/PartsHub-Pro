// Events
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String? phone;
  final String password;
  AuthRegisterRequested({
    required this.name,
    required this.email,
    this.phone,
    required this.password,
  });
}

class AuthLogoutRequested extends AuthEvent {}
