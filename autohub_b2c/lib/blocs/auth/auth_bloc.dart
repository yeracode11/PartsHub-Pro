import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/customer_model.dart';
import '../../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  static const _profileKey = 'b2c_customer_profile';

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final me = await _authService.getMe();
      if (me != null) {
        final customer = _customerFromUser(me);
        await _saveProfile(customer);
        emit(AuthAuthenticated(customer));
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final profileRaw = prefs.getString(_profileKey);
      final token = await _authService.hasToken();
      if (profileRaw != null && token) {
        final customer = Customer.fromJson(
          Map<String, dynamic>.from(json.decode(profileRaw)),
        );
        emit(AuthAuthenticated(customer));
        return;
      }

      emit(AuthUnauthenticated());
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _authService.login(event.email, event.password);
      await _authService.persistSession(result);
      final user = result['user'] as Map<String, dynamic>? ?? {};
      final customer = _customerFromUser(user);
      await _saveProfile(customer);
      emit(AuthAuthenticated(customer));
    } catch (e) {
      emit(AuthError('Неверный email или пароль. Войдите через аккаунт сервера.'));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _authService.register(
        name: event.name,
        email: event.email,
        password: event.password,
        phone: event.phone,
      );
      await _authService.persistSession(result);
      final user = result['user'] as Map<String, dynamic>? ?? {};
      final customer = _customerFromUser(user);
      await _saveProfile(customer);
      emit(AuthAuthenticated(customer));
    } catch (e) {
      emit(AuthError('Ошибка регистрации: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    await _authService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    emit(AuthUnauthenticated());
  }

  Customer _customerFromUser(Map<String, dynamic> user) {
    return Customer(
      id: user['id'] is int ? user['id'] : int.tryParse('${user['id']}') ?? 0,
      name: user['name']?.toString() ?? 'Пользователь',
      email: user['email']?.toString() ?? '',
      phone: user['phone']?.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _saveProfile(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, json.encode(customer.toJson()));
  }
}
