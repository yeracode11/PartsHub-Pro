import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/screens/auth/register_screen.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';
import 'package:autohub_b2b/widgets/auth/auth_form_field.dart';
import 'package:autohub_b2b/widgets/auth/auth_phone_field.dart';
import 'package:autohub_b2b/widgets/auth/auth_primary_button.dart';
import 'package:autohub_b2b/widgets/auth/auth_screen_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final canDismiss = Navigator.of(context, rootNavigator: true).canPop();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else if (state is AuthAuthenticated) {
          setState(() => _errorMessage = null);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final nav = Navigator.of(context, rootNavigator: true);
            if (nav.canPop()) {
              nav.pop();
            }
          });
        } else if (state is AuthLoading) {
          setState(() => _errorMessage = null);
        }
      },
      builder: (context, state) {
        return AuthScreenShell(
          errorMessage: _errorMessage,
          leading: canDismiss
              ? AuthIconButton(
                  icon: Icons.close,
                  tooltip: 'Закрыть',
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).maybePop(),
                )
              : null,
          form: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthPhoneField(
                  controller: _phoneController,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AuthFormField(
                  controller: _passwordController,
                  label: 'Пароль',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(state),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AuthDesign.textMuted,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите пароль';
                    }
                    if (value.length < 6) {
                      return 'Пароль должен быть минимум 6 символов';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'Войти',
                  isLoading: state is AuthLoading,
                  onPressed: state is AuthLoading ? null : () => _submit(state),
                ),
              ],
            ),
          ),
          footer: AuthLinkRow(
            prompt: 'Нет аккаунта?',
            actionLabel: 'Зарегистрироваться',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
          ),
        );
      },
    );
  }

  void _submit(AuthState state) {
    if (state is AuthLoading) return;
    if (_formKey.currentState?.validate() != true) return;

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          AuthSignInRequested(
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
