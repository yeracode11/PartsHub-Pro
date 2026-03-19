import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/auth/secure_storage_service.dart';
import 'package:autohub_b2b/screens/profile/edit_profile_screen.dart';
import 'package:autohub_b2b/screens/legal/privacy_policy_screen.dart';
import 'package:autohub_b2b/screens/legal/terms_of_use_screen.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _organizationName;
  String? _organizationPhone;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrganizationName();
  }

  Future<void> _loadOrganizationName() async {
    final storage = SecureStorageService();
    final userData = await storage.getUserData();
    if (userData != null && userData['organization'] != null) {
      final organization = userData['organization'];
      setState(() {
        _organizationName = organization['name'] as String?;
        _organizationPhone = (organization['phone'] as String?) ?? userData['phone'] as String?;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Профиль'),
        elevation: 0,
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // Если пользователь вышел, закрываем экран профиля
          if (state is AuthUnauthenticated) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return _buildProfileContent(context, state.user);
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
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
                  if (_organizationName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _organizationName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                if (_organizationName != null) ...[
                  _buildInfoTile(
                    icon: Icons.business_center,
                    title: 'Организация',
                    value: _organizationName!,
                  ),
                  const Divider(height: 1),
                ],
                if (_organizationPhone != null && _organizationPhone!.isNotEmpty) ...[
                  _buildInfoTile(
                    icon: Icons.phone,
                    title: 'Телефон',
                    value: _organizationPhone!,
                  ),
                  const Divider(height: 1),
                ],
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
                if (user.role == UserRole.owner)
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Редактировать профиль'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(user: user),
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
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Правовая информация
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Политика конфиденциальности'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Пользовательское соглашение'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TermsOfUseScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('О приложении'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAboutAppDialog(context),
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

          const SizedBox(height: 12),

          // Удалить аккаунт (Apple requirement)
          Center(
            child: TextButton(
              onPressed: () => _showDeleteAccountDialog(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade300,
              ),
              child: const Text('Удалить аккаунт'),
            ),
          ),

          const SizedBox(height: 8),
          const Center(
            child: Text(
              'AutoHub B2B v1.0.0',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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

  void _showDeleteAccountDialog(BuildContext context) {
    DialogHelper.showConfirm(
      context: context,
      title: 'Удалить аккаунт?',
      message: 'Это действие необратимо. Все ваши данные, включая товары, '
          'заказы, клиенты и аналитику, будут безвозвратно удалены.\n\n'
          'Для подтверждения удаления отправьте запрос на eracode11@gmail.com '
          'с указанием email аккаунта. Данные будут удалены в течение 30 дней.',
      confirmText: 'Удалить аккаунт',
      isDestructive: true,
      onConfirm: (ctx) async {
        Navigator.pop(ctx);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Для удаления аккаунта отправьте запрос на eracode11@gmail.com',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      },
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'AutoHub B2B',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 ТОО «AutoHub». Все права защищены.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'B2B-платформа для управления автобизнесом: '
          'авторазборы, автосервисы, автомойки.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          'Email: eracode11@gmail.com',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    DialogHelper.showConfirm(
      context: context,
      title: 'Выход из аккаунта',
      message: 'Вы уверены, что хотите выйти из аккаунта?',
      confirmText: 'Выйти',
      isDestructive: true,
      onConfirm: (ctx) async {
        Navigator.pop(ctx);
        if (context.mounted) {
          authBloc.add(AuthSignOutRequested());
        }
      },
    );
  }
}

