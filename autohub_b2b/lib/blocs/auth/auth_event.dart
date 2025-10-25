import 'package:equatable/equatable.dart';
import 'package:autohub_b2b/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final UserRole role;
  final BusinessType businessType;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    required this.businessType,
  });

  @override
  List<Object?> get props => [email, password, name, role, businessType];
}

class AuthSignOutRequested extends AuthEvent {}

