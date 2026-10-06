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
import 'package:autohub_b2b/screens/settings/settings_screen.dart';
import 'package:autohub_b2b/screens/legal/terms_of_use_screen.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';
import 'package:autohub_b2b/core/phone/phone_utils.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/widgets/auth/auth_phone_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _organizationName;
  String? _organizationPhone;
  List<Map<String, dynamic>> _masters = [];
  bool _mastersLoading = false;
  bool _mastersRequested = false;

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
      if (mounted) {
        setState(() {
          _organizationName = organization['name'] as String?;
          _organizationPhone = (organization['phone'] as String?) ?? userData['phone'] as String?;
        });
      }
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

  Future<void> _loadMasters() async {
    setState(() => _mastersLoading = true);
    try {
      final response = await ApiClient().dio.get('/api/users/staff');
      if (!mounted) return;
      setState(() {
        _masters = (response.data as List).cast<Map<String, dynamic>>();
        _mastersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _mastersLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    }
  }

  Future<void> _addMaster() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddMasterDialog(),
    );
    if (created == true) _loadMasters();
  }

  String _staffSubtitle(Map<String, dynamic> master) {
    final phone = master['phone']?.toString() ?? '';
    final role = master['role'] == 'sto' ? 'СТО' : 'Мастер';
    if (master['role'] == 'sto') return '$role · $phone';
    return '$role · $phone · ${_payLabel(master)}';
  }

  String _payLabel(Map<String, dynamic> master) {
    final rate = master['payRate'];
    final value = rate is num ? rate : num.tryParse('$rate') ?? 40;
    if (master['payType'] == 'hourly') {
      return '${value.toString()} ₸/час';
    }
    return '$value%';
  }

  Future<void> _editPay(Map<String, dynamic> master) async {
    var type = master['payType'] == 'hourly' ? 'hourly' : 'percent';
    final rate = TextEditingController(text: '${master['payRate'] ?? 40}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(master['name']?.toString() ?? 'Оплата мастера'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(
                  labelText: 'Начисление',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('Процент от работы')),
                  DropdownMenuItem(value: 'hourly', child: Text('Ставка за час')),
                ],
                onChanged: (value) => setLocal(() => type = value ?? 'percent'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: type == 'hourly' ? '₸ за нормо-час' : 'Процент',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    final raw = rate.text.trim().replaceAll(',', '.');
    rate.dispose();
    if (saved != true) return;
    try {
      await ApiClient().dio.patch('/api/users/staff/${master['id']}', data: {
        'payType': type,
        'payRate': double.tryParse(raw) ?? 40,
      });
      _loadMasters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  Future<void> _removeMaster(Map<String, dynamic> master) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить мастера?'),
        content: Text(master['name']?.toString() ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient().dio.delete('/api/users/staff/${master['id']}');
      _loadMasters();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  Widget _buildMastersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Сотрудники',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Добавить сотрудника',
                  onPressed: _addMaster,
                  icon: const Icon(Icons.person_add_outlined),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 8),
              child: Text(
                'СТО ведёт запись. Мастер выполняет работы.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            if (_mastersLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_masters.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 4, 8, 12),
                child: Text('Мастеров пока нет'),
              )
            else
              ..._masters.map(
                (master) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(master['name']?.toString() ?? ''),
                  subtitle: Text(_staffSubtitle(master)),
                  onTap: master['role'] == 'sto' ? null : () => _editPay(master),
                  trailing: IconButton(
                    tooltip: 'Удалить',
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeMaster(master),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserModel user) {
    final isOwner = user.role == UserRole.owner;
    if (isOwner && !_mastersRequested) {
      _mastersRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMasters();
      });
    }

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
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        icon: Icons.badge,
                        label: user.role.displayName,
                        color: AppTheme.primaryColor,
                      ),
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
          if (isOwner) ...[
            const SizedBox(height: 24),
            _buildMastersCard(),
          ],
          const SizedBox(height: 24),

          // Действия
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Редактировать профиль'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(user: user),
                      ),
                    );
                    if (context.mounted) {
                      await _loadOrganizationName();
                    }
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
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _AddMasterDialog extends StatefulWidget {
  const _AddMasterDialog();

  @override
  State<_AddMasterDialog> createState() => _AddMasterDialogState();
}

class _AddMasterDialogState extends State<_AddMasterDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _phoneKey = GlobalKey<AuthPhoneFieldState>();
  final _rate = TextEditingController(text: '40');
  String _payType = 'percent';
  String _role = 'worker';
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final country = _phoneKey.currentState?.country ?? PhoneCountry.kazakhstan;
    final phone = PhoneUtils.normalizeToE164(
      _phone.text.trim(),
      country: country,
      nationalDigitsOnly: true,
    );
    final password = _password.text;
    if (name.isEmpty || phone == null || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя, телефон и пароль от 6 символов')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient().dio.post('/api/users/staff', data: {
        'name': name,
        'phone': phone,
        'password': password,
        'payType': _payType,
        'payRate': double.tryParse(_rate.text.trim().replaceAll(',', '.')) ?? 40,
        'role': _role,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый сотрудник'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AuthPhoneField(
              key: _phoneKey,
              controller: _phone,
              variant: PhoneFieldVariant.profile,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Пароль',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: const InputDecoration(
                labelText: 'Роль',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'worker', child: Text('Мастер')),
                DropdownMenuItem(value: 'sto', child: Text('СТО')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'worker'),
            ),
            if (_role == 'worker') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _payType,
              decoration: const InputDecoration(
                labelText: 'Начисление',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'percent', child: Text('Процент от работы')),
                DropdownMenuItem(value: 'hourly', child: Text('Ставка за час')),
              ],
              onChanged: (value) => setState(() => _payType = value ?? 'percent'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _payType == 'hourly' ? '₸ за нормо-час' : 'Процент',
                border: const OutlineInputBorder(),
              ),
            ),
            ],
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

