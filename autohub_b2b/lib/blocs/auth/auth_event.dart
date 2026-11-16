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
  final String name;
  final String organizationName;
  /// service — СТО, parts — авторазбор.
  final String businessType;
  /// Регистрация создаёт владельца. Мастера добавляет владелец в профиле.
  final String role;
  /// Токен WhatsApp-подтверждения номера (null — сервер не требует).
  final String? phoneVerificationToken;

  const AuthSignUpRequested({
    required this.phone,
    required this.password,
    required this.name,
    required this.organizationName,
    required this.businessType,
    this.role = 'owner',
    this.phoneVerificationToken,
  });

  @override
  List<Object?> get props => [
        phone,
        password,
        name,
        organizationName,
        businessType,
        role,
        phoneVerificationToken,
      ];
}

/// Вход без пароля после подтверждения номера в WhatsApp.
class AuthWhatsAppSignInRequested extends AuthEvent {
  final String verificationToken;

  const AuthWhatsAppSignInRequested(this.verificationToken);

  @override
  List<Object?> get props => [verificationToken];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthProfileUpdated extends AuthEvent {
  final UserModel user;

  const AuthProfileUpdated(this.user);

  @override
  List<Object?> get props => [user];
}
