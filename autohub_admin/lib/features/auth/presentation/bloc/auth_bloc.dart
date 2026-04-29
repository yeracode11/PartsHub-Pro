import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_token_storage.dart';
import '../../data/auth_api.dart';
import '../../data/models/admin_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthApi authApi,
    required SecureTokenStorage tokenStorage,
  })  : _authApi = authApi,
        _tokenStorage = tokenStorage,
        super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginSubmitted>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSessionExpired>(_onExpired);
  }

  final AuthApi _authApi;
  final SecureTokenStorage _tokenStorage;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final token = await _tokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }

    try {
      final user = await _authApi.me();
      _emitForRole(user, emit);
    } catch (_) {
      await _tokenStorage.clearAll();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginSubmitted event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final session = await _authApi.login(email: event.email, password: event.password);
      await _tokenStorage.writeAccessToken(session.accessToken);
      await _tokenStorage.writeRefreshToken(session.refreshToken);
      _emitForRole(session.user, emit);
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  void _emitForRole(AdminUser user, Emitter<AuthState> emit) {
    if (user.role != AppConfig.superadminRole) {
      emit(AuthAccessDenied(user));
      return;
    }
    emit(AuthAuthenticated(user));
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _tokenStorage.clearAll();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onExpired(AuthSessionExpired event, Emitter<AuthState> emit) async {
    await _tokenStorage.clearAll();
    emit(const AuthUnauthenticated());
  }
}
