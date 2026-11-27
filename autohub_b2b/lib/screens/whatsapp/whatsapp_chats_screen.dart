import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/api/whatsapp_web_service.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_chat_screen.dart';

/// Все чаты WhatsApp магазина (канал по QR). Обновляется каждые 5 секунд.
class WhatsAppChatsScreen extends StatefulWidget {
  const WhatsAppChatsScreen({super.key});

  @override
  State<WhatsAppChatsScreen> createState() => _WhatsAppChatsScreenState();
}

class _WhatsAppChatsScreenState extends State<WhatsAppChatsScreen> {
  late final WhatsAppWebService _service;
  List<WhatsAppChatSummary>? _chats;
  String? _error;
  String _query = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _service = WhatsAppWebService(ApiClient());
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chats = await _service.chats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = userFacingApiMessage(
          e,
          prefix: 'Не удалось загрузить чаты',
        ),
      );
    }
  }

  Future<void> _openChat(String phone, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WhatsAppChatScreen(phone: phone, title: title),
      ),
    );
    await _load();
  }

  Future<void> _newChat() async {
    final controller = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый чат'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Номер покупателя',
            hintText: '+7 701 123 45 67',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
    controller.dispose();
    var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.length < 10) return;
    if (!mounted) return;
    await _openChat(digits, '+$digits');
  }

  @override
  Widget build(BuildContext context) {
    final chats = (_chats ?? const <WhatsAppChatSummary>[])
        .where(
          (c) =>
              _query.isEmpty ||
              c.title.toLowerCase().contains(_query) ||
              c.phone.contains(_query),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Чаты WhatsApp')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Новый чат'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Имя или номер',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
          Expanded(
            child: _chats == null
                ? const Center(child: CircularProgressIndicator())
                : chats.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Пока нет сообщений. Новые чаты появятся здесь, '
                        'как только покупатель напишет на номер магазина.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _ChatTile(
                        chat: chats[i],
                        onTap: () => _openChat(chats[i].phone, chats[i].title),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});

  final WhatsAppChatSummary chat;
  final VoidCallback onTap;

  String _time(DateTime t) {
    final now = DateTime.now();
    final sameDay =
        t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? DateFormat.Hm().format(t) : DateFormat('dd.MM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppTheme.successSoft,
        child: Text(
          chat.title.characters.first.toUpperCase(),
          style: const TextStyle(color: AppTheme.successColor),
        ),
      ),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${chat.lastIsOutbound ? 'Вы: ' : ''}${chat.lastMessage}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _time(chat.lastAt),
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }
}
