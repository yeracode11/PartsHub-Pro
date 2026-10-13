import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Автонапоминания клиентам о ТО через WhatsApp (GET/PUT /api/service-reminders).
class ServiceRemindersScreen extends StatefulWidget {
  const ServiceRemindersScreen({super.key, required this.canEdit});

  /// Менять настройки и запускать отправку может только владелец.
  final bool canEdit;

  @override
  State<ServiceRemindersScreen> createState() => _ServiceRemindersScreenState();
}

class _ServiceRemindersScreenState extends State<ServiceRemindersScreen> {
  final _dio = ApiClient().dio;
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get('/api/service-reminders');
      if (!mounted) return;
      setState(() {
        _data = Map<String, dynamic>.from(response.data as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is DioException && e.response?.statusCode == 404
            ? 'Сервер ещё не обновлён: напоминания недоступны.'
            : userFacingApiMessage(e);
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _settings =>
      Map<String, dynamic>.from(_data!['settings'] as Map);

  Future<void> _update(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await _dio.put('/api/service-reminders/settings', data: patch);
      await _load();
    } catch (e) {
      _snack(userFacingApiMessage(e, prefix: 'Не сохранено'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow() async {
    setState(() => _saving = true);
    try {
      final response = await _dio.post('/api/service-reminders/run');
      final result = Map<String, dynamic>.from(response.data as Map);
      if (result['skipped'] == 'template') {
        _snack('Шаблон ещё не одобрен Meta — отправка начнётся после одобрения');
      } else {
        _snack(
          'Отправлено: ${result['sent']}'
          '${(result['failed'] ?? 0) > 0 ? ', ошибок: ${result['failed']}' : ''}',
        );
      }
      await _load();
    } catch (e) {
      _snack(userFacingApiMessage(e, prefix: 'Ошибка'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppTheme.errorColor : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Напоминания о ТО')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSettingsCard(),
                  const SizedBox(height: 16),
                  _buildUpcoming(),
                  const SizedBox(height: 16),
                  _buildRecent(),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsCard() {
    final settings = _settings;
    final enabled = settings['enabled'] == true;
    final days = (settings['daysBefore'] as num?)?.toInt() ?? 3;
    final connections = (_data!['connections'] as List? ?? const [])
        .map((c) => Map<String, dynamic>.from(c as Map))
        .toList();
    final editable = widget.canEdit && !_saving;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Напоминать клиентам о ТО'),
              subtitle: const Text(
                'WhatsApp-сообщение клиенту, когда подходит дата следующего ТО',
              ),
              value: enabled,
              onChanged: editable
                  ? (value) => _update({'enabled': value})
                  : null,
            ),
            if (connections.isEmpty)
              const Text(
                'Нет подключённого номера WhatsApp. Подключите его в разделе WhatsApp.',
                style: TextStyle(color: AppTheme.warningColor),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: days,
              decoration: const InputDecoration(labelText: 'Когда писать'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('В день ТО')),
                DropdownMenuItem(value: 1, child: Text('За 1 день')),
                DropdownMenuItem(value: 3, child: Text('За 3 дня')),
                DropdownMenuItem(value: 7, child: Text('За неделю')),
              ],
              onChanged: editable
                  ? (value) => _update({'daysBefore': value})
                  : null,
            ),
            if (connections.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: settings['connectionId'] as String?,
                decoration: const InputDecoration(labelText: 'С какого номера'),
                items: [
                  for (final c in connections)
                    DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(
                        (c['displayName'] ?? c['phoneNumber'] ?? c['id'])
                            .toString(),
                      ),
                    ),
                ],
                onChanged: editable
                    ? (value) => _update({'connectionId': value})
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            _buildTemplateStatus(settings),
            if (widget.canEdit && enabled) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving ? null : _runNow,
                child: const Text('Отправить сейчас'),
              ),
            ],
            if (!widget.canEdit) ...[
              const SizedBox(height: 12),
              const Text(
                'Изменить настройки может владелец.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateStatus(Map<String, dynamic> settings) {
    final status = settings['templateStatus'] as String?;
    final error = settings['templateError'] as String?;
    final (String text, Color color) = switch (status) {
      'APPROVED' => ('Шаблон сообщения одобрен Meta', AppTheme.successColor),
      'PENDING' => (
        'Шаблон на проверке у Meta — обычно от нескольких минут до суток',
        AppTheme.warningColor,
      ),
      'REJECTED' => ('Meta отклонила шаблон', AppTheme.errorColor),
      'MISSING' => ('Шаблон не создан', AppTheme.errorColor),
      null => ('Шаблон будет создан при включении', AppTheme.textSecondary),
      _ => ('Статус шаблона: $status', AppTheme.textSecondary),
    };
    final template = Map<String, dynamic>.from(_data!['template'] as Map);
    final preview = (template['body'] as String)
        .replaceAll('{{1}}', 'Иван')
        .replaceAll('{{2}}', 'Toyota Camry 110ERS11')
        .replaceAll('{{3}}', '20.10.2026');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        if (error != null && error.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Text(preview, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildUpcoming() {
    final upcoming = (_data!['upcoming'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return _section(
      'Кому напомним',
      upcoming.isEmpty
          ? const [
              Text(
                'В ближайшие дни ТО ни у кого не запланировано.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ]
          : [
              for (final r in upcoming)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${r['customerName']} · ${r['car']}'),
                  subtitle: Text('ТО ${_date(r['dueDate'])} · ${r['phone']}'),
                ),
            ],
    );
  }

  Widget _buildRecent() {
    final recent = (_data!['recent'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return _section('Последние отправки', [
      for (final r in recent)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('${r['customerName'] ?? 'Клиент'} · ${r['car'] ?? ''}'),
          subtitle: r['status'] == 'sent'
              ? Text('ТО ${_date(r['dueDate'])} · отправлено')
              : Text(
                  'Ошибка: ${r['error'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
        ),
    ]);
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.sectionTitle),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  String _date(Object? iso) {
    final date = DateTime.tryParse(iso?.toString() ?? '');
    return date == null ? '—' : DateFormat('dd.MM.yyyy').format(date);
  }
}
