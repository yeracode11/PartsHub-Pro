import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/screens/legal/privacy_policy_screen.dart';
import 'package:autohub_b2b/screens/legal/terms_of_use_screen.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';
import 'package:autohub_b2b/widgets/auth/auth_form_field.dart';
import 'package:autohub_b2b/widgets/auth/auth_phone_field.dart';
import 'package:autohub_b2b/widgets/auth/auth_primary_button.dart';
import 'package:autohub_b2b/widgets/auth/auth_screen_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          setState(() => _errorMessage = state.message);
        } else if (state is AuthAuthenticated) {
          setState(() => _errorMessage = null);
          Navigator.of(context).pop();
        } else if (state is AuthLoading) {
          setState(() => _errorMessage = null);
        }
      },
      builder: (context, state) {
        return AuthScreenShell(
          subtitle: 'Регистрация по номеру телефона',
          errorMessage: _errorMessage,
          leading: AuthIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Назад',
            onPressed: () => Navigator.of(context).pop(),
          ),
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
                  textInputAction: TextInputAction.next,
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
                const SizedBox(height: 16),
                AuthFormField(
                  controller: _confirmPasswordController,
                  label: 'Подтвердите пароль',
                  icon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(state),
                  suffix: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AuthDesign.textMuted,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Подтвердите пароль';
                    }
                    if (value != _passwordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _TermsCheckbox(
                  agreed: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'Зарегистрироваться',
                  isLoading: state is AuthLoading,
                  onPressed: state is AuthLoading ? null : () => _submit(state),
                ),
              ],
            ),
          ),
          footer: AuthLinkRow(
            prompt: 'Уже есть аккаунт?',
            actionLabel: 'Войти',
            onAction: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _submit(AuthState state) {
    if (state is AuthLoading) return;
    if (_formKey.currentState?.validate() != true) return;
    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Примите пользовательское соглашение');
      return;
    }

    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          AuthSignUpRequested(
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.agreed,
    required this.onChanged,
  });

  final bool agreed;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: agreed,
      validator: (value) {
        if (value != true) return 'Необходимо принять условия';
        return null;
      },
      builder: (formState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: agreed,
                    activeColor: AuthDesign.primary,
                    onChanged: (v) {
                      onChanged(v);
                      formState.didChange(v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AuthDesign.textMuted,
                        height: 1.45,
                      ),
                      children: [
                        const TextSpan(text: 'Я принимаю '),
                        TextSpan(
                          text: 'Пользовательское соглашение',
                          style: const TextStyle(
                            color: AuthDesign.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TermsOfUseScreen(),
                                ),
                              );
                            },
                        ),
                        const TextSpan(text: ' и '),
                        TextSpan(
                          text: 'Политику конфиденциальности',
                          style: const TextStyle(
                            color: AuthDesign.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (formState.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 6),
                child: Text(
                  formState.errorText!,
                  style: const TextStyle(color: AuthDesign.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
