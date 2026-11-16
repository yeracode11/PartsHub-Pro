import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/auth/whatsapp_verification_service.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';
import 'package:autohub_b2b/widgets/auth/auth_primary_button.dart';
import 'package:autohub_b2b/widgets/auth/auth_screen_shell.dart';

/// Итог экрана подтверждения.
sealed class WhatsAppVerifyResult {
  const WhatsAppVerifyResult();
}

/// Номер подтверждён: токен передаётся в register/login.
final class WhatsAppVerified extends WhatsAppVerifyResult {
  const WhatsAppVerified(this.verificationToken);
  final String verificationToken;
}

/// На сервере подтверждение выключено (нет номера бота) — продолжаем без него.
final class WhatsAppVerificationUnavailable extends WhatsAppVerifyResult {
  const WhatsAppVerificationUnavailable();
}

/// Пользователь отправляет код боту Vinly в WhatsApp, экран ждёт подтверждения.
///
/// Возвращает [WhatsAppVerifyResult] через Navigator.pop или null, если закрыли.
class WhatsAppVerifyScreen extends StatefulWidget {
  const WhatsAppVerifyScreen({
    super.key,
    required this.phone,
    required this.purpose,
    this.service,
  });

  /// Номер в E.164.
  final String phone;
  final WhatsAppVerificationPurpose purpose;
  final WhatsAppVerificationService? service;

  static Future<WhatsAppVerifyResult?> open(
    BuildContext context, {
    required String phone,
    required WhatsAppVerificationPurpose purpose,
  }) {
    return Navigator.of(context).push<WhatsAppVerifyResult>(
      MaterialPageRoute(
        builder: (_) => WhatsAppVerifyScreen(phone: phone, purpose: purpose),
      ),
    );
  }

  @override
  State<WhatsAppVerifyScreen> createState() => _WhatsAppVerifyScreenState();
}

class _WhatsAppVerifyScreenState extends State<WhatsAppVerifyScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 3);

  late final WhatsAppVerificationService _service =
      widget.service ?? WhatsAppVerificationService();

  WhatsAppVerificationTicket? _ticket;
  Timer? _pollTimer;
  bool _starting = true;
  bool _expired = false;
  bool _checking = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Пользователь вернулся из WhatsApp — сразу проверяем, не ждём таймер.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkStatus());
    }
  }

  Future<void> _start() async {
    _pollTimer?.cancel();
    setState(() {
      _starting = true;
      _expired = false;
      _error = null;
    });
    try {
      final ticket = await _service.start(
        phone: widget.phone,
        purpose: widget.purpose,
      );
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _starting = false;
      });
      _pollTimer = Timer.periodic(_pollInterval, (_) => _checkStatus());
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 503 &&
          widget.purpose == WhatsAppVerificationPurpose.register) {
        Navigator.of(context).pop(const WhatsAppVerificationUnavailable());
        return;
      }
      setState(() {
        _starting = false;
        _error = userFacingApiMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = userFacingApiMessage(e);
      });
    }
  }

  Future<void> _checkStatus() async {
    final ticket = _ticket;
    if (ticket == null || _checking || _done || _expired) return;
    _checking = true;
    try {
      final status = await _service.status(ticket);
      if (!mounted) return;
      switch (status.state) {
        case WhatsAppVerificationState.verified:
          final token = status.verificationToken;
          if (token == null) return;
          _done = true;
          _pollTimer?.cancel();
          Navigator.of(context).pop(WhatsAppVerified(token));
        case WhatsAppVerificationState.expired:
        case WhatsAppVerificationState.consumed:
          _pollTimer?.cancel();
          setState(() => _expired = true);
        case WhatsAppVerificationState.pending:
          if (ticket.expiresAt.isBefore(DateTime.now())) {
            _pollTimer?.cancel();
            setState(() => _expired = true);
          }
      }
    } catch (_) {
      // Сеть моргнула — следующий тик таймера попробует снова.
    } finally {
      _checking = false;
    }
  }

  Future<void> _openWhatsApp() async {
    final ticket = _ticket;
    if (ticket == null) return;
    final opened = await launchUrl(
      Uri.parse(ticket.waLink),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error =
          'Не удалось открыть WhatsApp. Отправьте код вручную на +${ticket.botPhone}');
    }
  }

  Future<void> _copyCode() async {
    final ticket = _ticket;
    if (ticket == null) return;
    await Clipboard.setData(ClipboardData(text: ticket.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Код скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return AuthScreenShell(
      subtitle: 'Подтвердите номер через WhatsApp',
      errorMessage: _error,
      leading: AuthIconButton(
        icon: Icons.arrow_back,
        tooltip: 'Назад',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      form: _starting
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          : ticket == null
              ? AuthPrimaryButton(label: 'Повторить', onPressed: _start)
              : _expired
                  ? _ExpiredBody(onRetry: _start)
                  : _PendingBody(
                      phone: widget.phone,
                      ticket: ticket,
                      onOpenWhatsApp: _openWhatsApp,
                      onCopyCode: _copyCode,
                    ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  const _PendingBody({
    required this.phone,
    required this.ticket,
    required this.onOpenWhatsApp,
    required this.onCopyCode,
  });

  final String phone;
  final WhatsAppVerificationTicket ticket;
  final VoidCallback onOpenWhatsApp;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Нажмите кнопку ниже и отправьте готовое сообщение в WhatsApp '
          'с номера $phone. Это бесплатно, SMS не нужна.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AuthDesign.textMuted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          label: 'Код подтверждения ${ticket.code.split('').join(' ')}',
          button: true,
          child: InkWell(
            onTap: onCopyCode,
            borderRadius: AuthDesign.fieldRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AuthDesign.surface,
                borderRadius: AuthDesign.fieldRadius,
                border: Border.all(color: AuthDesign.border),
              ),
              child: ExcludeSemantics(
                child: Text(
                  ticket.code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    color: AuthDesign.text,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Открыть WhatsApp',
          onPressed: onOpenWhatsApp,
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Ждём ваше сообщение…',
                style: TextStyle(color: AuthDesign.textMuted, fontSize: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Не открывается? Отправьте код ${ticket.code} на номер '
          '+${ticket.botPhone} в WhatsApp.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AuthDesign.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Время на подтверждение истекло.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: AuthDesign.textMuted),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Получить новый код', onPressed: onRetry),
      ],
    );
  }
}
