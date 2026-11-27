import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/api/whatsapp_web_service.dart';

/// Переписка с одним покупателем. Новые сообщения подтягиваются раз в 3 секунды.
class WhatsAppChatScreen extends StatefulWidget {
  const WhatsAppChatScreen({
    super.key,
    required this.phone,
    required this.title,
  });

  final String phone;
  final String title;

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  late final WhatsAppWebService _service;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<WhatsAppChatMessage>? _messages;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = WhatsAppWebService(ApiClient());
    _load(scrollToEnd: true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool scrollToEnd = false}) async {
    try {
      final messages = await _service.messages(widget.phone);
      if (!mounted) return;
      final grew = (messages.length) != (_messages?.length ?? 0);
      setState(() => _messages = messages);
      if (scrollToEnd || grew) _jumpToEnd();
    } catch (_) {
      // при опросе молчим; ошибка отправки показывается отдельно
      if (mounted && _messages == null) setState(() => _messages = const []);
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await _service.send(widget.phone, text);
      _input.clear();
      await _load(scrollToEnd: true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(userFacingApiMessage(e, prefix: 'Не отправлено')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.title != '+${widget.phone}')
              Text(
                '+${widget.phone}',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _Bubble(message: messages[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Сообщение',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Отправить',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final WhatsAppChatMessage message;

  String? get _sourceLabel {
    switch (message.source) {
      case 'bot':
        return 'Бот';
      case 'phone':
        return 'С телефона';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = message.isOutbound;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    return Align(
      alignment: out
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(200, 520)),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: out ? AppTheme.successSoft : AppTheme.surfaceColor,
          border: Border.all(
            color: message.failed ? AppTheme.errorColor : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.text),
            const SizedBox(height: 4),
            Text(
              [
                if (_sourceLabel != null) _sourceLabel!,
                DateFormat('dd.MM HH:mm').format(message.sentAt),
                if (message.failed) 'не доставлено',
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
