import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_event.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/utils/auth_navigation.dart';
import 'package:autohub_b2b/screens/auth/register_screen.dart';
import 'package:autohub_b2b/screens/legal/privacy_policy_screen.dart';
import 'package:autohub_b2b/screens/legal/terms_of_use_screen.dart';
import 'package:autohub_b2b/screens/onboarding/onboarding_screen.dart';
import 'package:autohub_b2b/screens/profile/profile_screen.dart';
import 'package:autohub_b2b/screens/warehouse/printer_settings_screen.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';

/// Центральный экран настроек: аккаунт, оборудование, приложение, документы, выход.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    final showBack = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: showBack
          ? AppBar(
              title: const Text('Настройки'),
              backgroundColor: AppTheme.surfaceColor,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
            )
          : null,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return ListView(
            children: [
              if (authState is! AuthAuthenticated) ...[
                _sectionHeader('Аккаунт'),
                _card(context, [
                  ListTile(
                    leading: const Icon(Icons.login, color: AppTheme.primaryColor),
                    title: const Text('Войти'),
                    subtitle: const Text('Доступ к данным организации и синхронизации'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AuthNavigation.pushLoginOverlay(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_outlined),
                    title: const Text('Создать аккаунт'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          fullscreenDialog: true,
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                  ),
                ]),
              ] else ...[
                _sectionHeader('Аккаунт'),
                _card(context, [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Профиль и организация'),
                    subtitle: Text(
                      authState.user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                ]),
              ],
              _sectionHeader('Рабочее место'),
              _card(context, [
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('Принтер этикеток'),
                  subtitle: const Text('Термопринтер, размер и подключение'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const PrinterSettingsScreen(),
                      ),
                    );
                  },
                ),
              ]),
              _sectionHeader('Приложение'),
              _card(context, [
                ListTile(
                  leading: const Icon(Icons.slideshow_outlined),
                  title: const Text('Знакомство с приложением'),
                  subtitle: const Text('Короткий тур по основным возможностям'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openOnboarding(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Уведомления'),
                  subtitle: const Text(
                    'Push и баннеры настраиваются в параметрах устройства',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Уведомления приложения управляются в системных настройках телефона или ПК.',
                        ),
                      ),
                    );
                  },
                ),
              ]),
              _sectionHeader('Справка и документы'),
              _card(context, [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Политика конфиденциальности'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
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
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
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
                  onTap: () => _showAbout(context),
                ),
              ]),
              if (authState is AuthAuthenticated) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Выйти из аккаунта',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: Text(
                  _packageInfo != null
                      ? 'Версия ${_packageInfo!.version} · сборка ${_packageInfo!.buildNumber}'
                      : 'Версия…',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              if (Platform.isWindows) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'На Windows проверка обновлений выполняется средствами установщика приложения.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Future<void> _openOnboarding(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (ctx) => OnboardingScreen(
          onComplete: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final p = _packageInfo;
    showAboutDialog(
      context: context,
      applicationName: 'Auto+ Pro',
      applicationVersion: p != null ? '${p.version} (${p.buildNumber})' : '—',
      applicationLegalese: '© 2026 AutoHub B2B',
      children: const [
        SizedBox(height: 16),
        Text(
          'Платформа для автобизнеса: склад, продажи, клиенты, аналитика и связь с покупателями.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    DialogHelper.showConfirm(
      context: context,
      title: 'Выход из аккаунта',
      message: 'Вы уверены, что хотите выйти? Данные на устройстве останутся до следующего входа.',
      confirmText: 'Выйти',
      isDestructive: true,
      onConfirm: (dialogCtx) async {
        Navigator.pop(dialogCtx);
        if (context.mounted) {
          authBloc.add(AuthSignOutRequested());
        }
      },
    );
  }
}
