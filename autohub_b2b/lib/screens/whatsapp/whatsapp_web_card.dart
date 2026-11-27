import 'dart:async';

import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/api/whatsapp_web_service.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_chats_screen.dart';

/// Карточка «WhatsApp по QR»: подключение номера магазина как в WhatsApp Web,
/// QR, бот и переход к чатам.
class WhatsAppWebCard extends StatefulWidget {
  const WhatsAppWebCard({super.key, required this.isOwner});

  final bool isOwner;

  @override
  State<WhatsAppWebCard> createState() => _WhatsAppWebCardState();
}

class _WhatsAppWebCardState extends State<WhatsAppWebCard> {
  late final WhatsAppWebService _service;
  WhatsAppWebStatus? _status;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _service = WhatsAppWebService(ApiClient());
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
      _schedulePoll(status);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = userFacingApiMessage(
          e,
          prefix: 'Не удалось получить статус WhatsApp',
        ),
      );
    }
  }

  /// Пока показываем QR или идёт подключение, обновляем каждые 3 секунды:
  /// QR в WhatsApp меняется примерно раз в 20 секунд.
  void _schedulePoll(WhatsAppWebStatus status) {
    _poll?.cancel();
    if (status.isWaitingForScan || status.isConnecting) {
      _poll = Timer(const Duration(seconds: 3), _refresh);
    }
  }

  Future<void> _run(Future<WhatsAppWebStatus> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await action();
      if (!mounted) return;
      setState(() => _status = status);
      _schedulePoll(status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = userFacingApiMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmConnect() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подключить WhatsApp по QR'),
        content: const Text(
          'Номер магазина подключится как «Связанное устройство», так же как '
          'WhatsApp Web. Телефон продолжит работать как обычно.\n\n'
          'Это неофициальный способ. Чтобы WhatsApp не заблокировал номер, '
          'не рассылайте сообщения незнакомым людям. Vinly ограничивает '
          'скорость и число новых собеседников в сутки.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Показать QR'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(_service.connect);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отключить WhatsApp?'),
        content: const Text(
          'Vinly перестанет получать и отправлять сообщения с этого номера. '
          'История чатов сохранится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отключить'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(_service.logout);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'WhatsApp магазина (по QR)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Обновить',
                  onPressed: _busy ? null : _refresh,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (status != null)
              ..._body(status),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body(WhatsAppWebStatus s) {
    if (s.gatewayUnavailable) {
      return [
        _pill('Сервис WhatsApp недоступен', AppTheme.warningColor),
        const SizedBox(height: 8),
        Text(
          'Попробуйте обновить через минуту.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ];
    }

    if (s.isAuthorized) {
      return [
        _pill(
          'Подключён${s.phone != null ? ': +${s.phone}' : ''}',
          AppTheme.successColor,
        ),
        if (s.remainingToday != null) ...[
          const SizedBox(height: 8),
          Text(
            'Сегодня отправлено ${s.sentToday ?? 0}, осталось ${s.remainingToday}.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Бот отвечает покупателям'),
          subtitle: const Text(
            'Наличие и цены со склада. Молчит 2 часа, если вы ответили сами.',
          ),
          value: s.botEnabled,
          onChanged: !widget.isOwner || _busy
              ? null
              : (v) => _run(() => _service.setBotEnabled(v)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Открыть чаты'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WhatsAppChatsScreen(),
                  ),
                ),
              ),
            ),
            if (widget.isOwner) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy ? null : _confirmLogout,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Отключить'),
              ),
            ],
          ],
        ),
      ];
    }

    if (s.isWaitingForScan && s.qrPng != null) {
      return [
        _pill('Отсканируйте QR', AppTheme.primaryColor),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Image.memory(
              s.qrPng!,
              width: 260,
              height: 260,
              gaplessPlayback: true,
              semanticLabel: 'QR-код для подключения WhatsApp',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'На телефоне магазина: WhatsApp → Настройки → Связанные устройства → '
          'Привязка устройства. Наведите камеру на код.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
      ];
    }

    if (s.isConnecting || s.isWaitingForScan) {
      return [
        _pill('Подключаемся…', AppTheme.primaryColor),
        const SizedBox(height: 12),
        const LinearProgressIndicator(),
      ];
    }

    return [
      _pill('Не подключён', AppTheme.warningColor),
      const SizedBox(height: 8),
      Text(
        s.reasonText.isNotEmpty
            ? s.reasonText
            : 'Подключите свой номер WhatsApp по QR: все чаты с покупателями '
                  'будут в Vinly, а бот сможет отвечать о наличии и ценах.',
        style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
      ),
      if (widget.isOwner) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _confirmConnect,
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Подключить по QR'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    ];
  }

  Widget _pill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
