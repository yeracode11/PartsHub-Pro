import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/config/environment.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/meta_whatsapp_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Форма подключения Meta WhatsApp Cloud API.
///
/// Только `displayName` / `phoneNumberId` / `wabaId` — Meta access token
/// не собирается и не хранится в приложении (см. POST /api/whatsapp/connections).
class MetaWhatsAppConnectScreen extends StatefulWidget {
  const MetaWhatsAppConnectScreen({super.key});

  @override
  State<MetaWhatsAppConnectScreen> createState() =>
      _MetaWhatsAppConnectScreenState();
}

class _MetaWhatsAppConnectScreenState
    extends State<MetaWhatsAppConnectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneNumberIdController = TextEditingController();
  final _wabaIdController = TextEditingController();
  late final MetaWhatsAppService _service;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _service = MetaWhatsAppService(ApiClient());

    // Тестовые значения — только в dev-сборке, никогда в production.
    if (Environment.isDevelopment) {
      _displayNameController.text = 'AutoPlus Test WhatsApp';
      _phoneNumberIdController.text = '1398564366663975';
      _wabaIdController.text = '3483066548542535';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneNumberIdController.dispose();
    _wabaIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _service.createConnection(
        displayName: _displayNameController.text.trim(),
        phoneNumberId: _phoneNumberIdController.text.trim(),
        wabaId: _wabaIdController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_describeError(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Человекочитаемое сообщение. Если backend требует access token —
  /// объясняем причину, а не показываем техническое поле "accessToken".
  String _describeError(Object e) {
    final raw = userFacingApiMessage(e, prefix: 'Не удалось подключить WhatsApp');
    if (raw.toLowerCase().contains('accesstoken')) {
      return 'Подключение недоступно: backend требует настройку Meta '
          'access token на сервере. Обратитесь к администратору.';
    }
    return raw;
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Обязательное поле';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Подключить WhatsApp'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 96),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Meta WhatsApp Cloud API',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Данные из Meta Business Manager (WhatsApp → API Setup).',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Например: AutoPlus WhatsApp',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberIdController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number ID',
                  hintText: 'Из Meta Business Manager',
                  prefixIcon: Icon(Icons.tag_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _wabaIdController,
                decoration: const InputDecoration(
                  labelText: 'WABA ID',
                  hintText: 'WhatsApp Business Account ID',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                textInputAction: TextInputAction.done,
                validator: _requiredValidator,
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Подключить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
