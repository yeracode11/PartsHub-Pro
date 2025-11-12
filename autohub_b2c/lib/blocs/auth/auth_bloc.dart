import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/customer_model.dart';
import 'auth_event.dart';
import 'auth_state.dart';

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  void _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!isClosed) emit(AuthLoading());
    
    try {
      // Проверяем сохраненные токены авторизации
      await Future.delayed(const Duration(seconds: 1));
      
      // Проверка токенов будет реализована позже
      if (!isClosed) emit(AuthUnauthenticated());
    } catch (e) {
      if (!isClosed) emit(AuthError('Ошибка проверки авторизации: $e'));
    }
  }

  void _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!isClosed) emit(AuthLoading());
    
    try {
      // Авторизация через backend API
      await Future.delayed(const Duration(seconds: 2));
      
      // Временная mock авторизация (будет заменена на реальный API)
      if (event.email == 'demo@autohub.kz' && event.password == 'demo123') {
        final customer = Customer(
          id: 1,
          name: 'Демо Пользователь',
          email: 'demo@autohub.kz',
          phone: '+7 (777) 123-45-67',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        );
        if (!isClosed) emit(AuthAuthenticated(customer));
      } else {
        if (!isClosed) emit(AuthError('Неверный email или пароль'));
      }
    } catch (e) {
      if (!isClosed) emit(AuthError('Ошибка входа: $e'));
    }
  }

  void _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!isClosed) emit(AuthLoading());
    
    try {
      // Регистрация через backend API
      await Future.delayed(const Duration(seconds: 2));
      
      // Временная mock регистрация (будет заменена на реальный API)
      final customer = Customer(
        id: DateTime.now().millisecondsSinceEpoch,
        name: event.name,
        email: event.email,
        phone: event.phone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      if (!isClosed) emit(AuthAuthenticated(customer));
    } catch (e) {
      if (!isClosed) emit(AuthError('Ошибка регистрации: $e'));
    }
  }

  void _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (!isClosed) emit(AuthLoading());
    
    try {
      // Выход из системы
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!isClosed) emit(AuthUnauthenticated());
    } catch (e) {
      if (!isClosed) emit(AuthError('Ошибка выхода: $e'));
    }
  }
}
