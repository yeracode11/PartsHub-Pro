import 'package:equatable/equatable.dart';
import 'package:autohub_b2b/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String phone;
  final String password;

  const AuthSignInRequested({
    required this.phone,
    required this.password,
  });

  @override
  List<Object?> get props => [phone, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String phone;
  final String password;

  const AuthSignUpRequested({
    required this.phone,
    required this.password,
  });

  @override
  List<Object?> get props => [phone, password];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthProfileUpdated extends AuthEvent {
  final UserModel user;

  const AuthProfileUpdated(this.user);

  @override
  List<Object?> get props => [user];
}
