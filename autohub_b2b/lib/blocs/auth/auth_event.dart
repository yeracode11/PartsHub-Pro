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
  final String? organizationName;
  final String? businessType; // 'service', 'parts', 'wash'

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    this.organizationName,
    this.businessType,
  });

  @override
  List<Object?> get props => [email, password, name, organizationName, businessType];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthProfileUpdated extends AuthEvent {
  final UserModel user;

  const AuthProfileUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

