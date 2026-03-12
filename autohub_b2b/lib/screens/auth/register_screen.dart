import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedBusinessType;

  final List<Map<String, String>> _businessTypes = [
    {'value': 'service', 'label': 'Автосервис'},
    {'value': 'parts', 'label': 'Авторазбор'},
    {'value': 'wash', 'label': 'Автомойка'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (state is AuthAuthenticated) {
            // Навигация произойдет автоматически через роутер
            Navigator.of(context).pop(); // Закрываем экран регистрации
          }
        },
        builder: (context, state) {
          return _buildRegisterForm(context, state);
        },
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context, AuthState state) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Card(
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Логотип
                  Icon(
                    Icons.business,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  
                  // Заголовок
                  Text(
                    'Создать аккаунт',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Зарегистрируйте свою организацию',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Имя
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ваше имя',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите ваше имя';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email поле
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Введите корректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Телефон (обязательно)
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Телефон',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      hintText: '+7 777 123 45 67',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _PhoneMaskFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите номер телефона';
                      }
                      final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                      // +7 (XXX) XXX-XX-XX => 11 digits with country code.
                      if (digitsOnly.length != 11 || !digitsOnly.startsWith('7')) {
                        return 'Введите корректный номер телефона';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Пароль поле
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
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

                  // Подтверждение пароля
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Подтвердите пароль',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
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

                  // Название организации (опционально)
                  TextFormField(
                    controller: _organizationNameController,
                    decoration: const InputDecoration(
                      labelText: 'Название организации (необязательно)',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                      hintText: 'Оставите пустым для автогенерации',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Тип бизнеса
                  DropdownButtonFormField<String>(
                    value: _selectedBusinessType,
                    decoration: const InputDecoration(
                      labelText: 'Тип бизнеса',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: _businessTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type['value'],
                        child: Text(type['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBusinessType = value;
                      });
                    },
                    validator: (value) {
                      // Опционально, можно убрать если не обязательно
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Кнопка регистрации
                  FilledButton(
                    onPressed: state is AuthLoading
                        ? null
                        : () {
                            if (_formKey.currentState!.validate()) {
                              context.read<AuthBloc>().add(
                                    AuthSignUpRequested(
                                      email: _emailController.text.trim(),
                                      password: _passwordController.text,
                                      name: _nameController.text.trim(),
                                      phone: _phoneController.text.trim(),
                                      organizationName: _organizationNameController.text.trim().isEmpty
                                          ? null
                                          : _organizationNameController.text.trim(),
                                      businessType: _selectedBusinessType,
                                    ),
                                  );
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: state is AuthLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Зарегистрироваться',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Ссылка на вход
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Уже есть аккаунт? Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationNameController.dispose();
    super.dispose();
  }
}

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final normalizedDigits = digits.startsWith('7')
        ? digits
        : digits.startsWith('8')
            ? '7${digits.substring(1)}'
            : '7$digits';
    final limited = normalizedDigits.length > 11
        ? normalizedDigits.substring(0, 11)
        : normalizedDigits;

    final masked = _buildMask(limited);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  String _buildMask(String digits) {
    final buffer = StringBuffer('+7');
    if (digits.length > 1) {
      final area = digits.substring(1, digits.length > 4 ? 4 : digits.length);
      buffer.write(' ($area');
      if (digits.length >= 4) buffer.write(')');
    }
    if (digits.length > 4) {
      final first = digits.substring(4, digits.length > 7 ? 7 : digits.length);
      buffer.write(' $first');
    }
    if (digits.length > 7) {
      final second = digits.substring(7, digits.length > 9 ? 9 : digits.length);
      buffer.write('-$second');
    }
    if (digits.length > 9) {
      final third = digits.substring(9, digits.length > 11 ? 11 : digits.length);
      buffer.write('-$third');
    }
    return buffer.toString();
  }
}

