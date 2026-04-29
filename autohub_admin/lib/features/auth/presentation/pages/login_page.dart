import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('AutoHub Admin', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          'Доступ только для роли superadmin',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _email,
                          enabled: !loading,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          enabled: !loading,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: const InputDecoration(labelText: 'Password'),
                          onFieldSubmitted: (_) => _submit(context),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: loading ? null : () => _submit(context),
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
          AuthLoginSubmitted(
            email: _email.text.trim(),
            password: _password.text,
          ),
        );
  }
}
