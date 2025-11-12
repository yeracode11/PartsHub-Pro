import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/core/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Профиль'),
        elevation: 0,
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthAuthenticated) {
            return _buildProfileContent(context, state.user);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Аватар и основная информация
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Роль и тип бизнеса
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildBadge(
                        icon: Icons.badge,
                        label: user.role.displayName,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      _buildBadge(
                        icon: Icons.business,
                        label: user.businessType.displayName,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Информация о пользователе
          Card(
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.person,
                  title: 'Имя',
                  value: user.name,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.email,
                  title: 'Email',
                  value: user.email,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.badge,
                  title: 'Роль',
                  value: user.role.displayName,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.business,
                  title: 'Тип бизнеса',
                  value: user.businessType.displayName,
                ),
                const Divider(height: 1),
                _buildInfoTile(
                  icon: Icons.calendar_today,
                  title: 'Дата регистрации',
                  value: _formatDate(user.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Действия
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Редактировать профиль'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Реализовать редактирование профиля
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Редактирование профиля будет доступно в следующей версии'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: const Text('Изменить пароль'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Реализовать смену пароля
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Смена пароля будет доступна в следующей версии'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Настройки'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Переход в настройки
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Кнопка выхода
          FilledButton.icon(
            onPressed: () => _showLogoutDialog(context),
            icon: const Icon(Icons.logout),
            label: const Text('Выйти из аккаунта'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(AuthSignOutRequested());
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

