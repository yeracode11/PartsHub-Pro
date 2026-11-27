import 'dart:convert';
import 'dart:typed_data';

import 'package:autohub_b2b/services/api/api_client.dart';

/// Состояние номера магазина, подключённого по QR (как WhatsApp Web).
class WhatsAppWebStatus {
  WhatsAppWebStatus({
    required this.state,
    this.phone,
    this.reason,
    required this.botEnabled,
    this.qrDataUrl,
    this.sentToday,
    this.remainingToday,
    required this.gatewayUnavailable,
  });

  final String state;
  final String? phone;
  final String? reason;
  final bool botEnabled;
  final String? qrDataUrl;
  final int? sentToday;
  final int? remainingToday;
  final bool gatewayUnavailable;

  bool get isAuthorized => state == 'authorized';
  bool get isWaitingForScan => state == 'qr';
  bool get isConnecting => state == 'starting' || state == 'reconnecting';

  /// PNG из data:image/png;base64,... для Image.memory.
  Uint8List? get qrPng {
    final url = qrDataUrl;
    if (url == null || !url.contains(',')) return null;
    try {
      return base64Decode(url.substring(url.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  String get reasonText {
    switch (reason) {
      case 'logged_out_on_phone':
        return 'Устройство отвязано в телефоне. Подключите заново.';
      case 'banned':
        return 'WhatsApp заблокировал номер. Проверьте приложение на телефоне.';
      case 'qr_timeout':
        return 'QR не отсканировали вовремя. Запустите подключение ещё раз.';
      case 'connect_failed':
        return 'Не удалось связаться с WhatsApp. Попробуйте позже.';
      case 'connection_replaced':
        return 'Этот номер открыт в другом WhatsApp Web. Подключите заново.';
      default:
        return '';
    }
  }

  factory WhatsAppWebStatus.fromJson(Map<String, dynamic> json) {
    return WhatsAppWebStatus(
      state: (json['state'] as String?) ?? 'stopped',
      phone: json['phone'] as String?,
      reason: json['reason'] as String?,
      botEnabled: json['botEnabled'] == true,
      qrDataUrl: json['qrDataUrl'] as String?,
      sentToday: (json['sentToday'] as num?)?.toInt(),
      remainingToday: (json['remainingToday'] as num?)?.toInt(),
      gatewayUnavailable: json['gatewayUnavailable'] == true,
    );
  }
}

class WhatsAppChatSummary {
  WhatsAppChatSummary({
    required this.phone,
    this.name,
    required this.lastMessage,
    required this.lastIsOutbound,
    required this.lastAt,
  });

  final String phone;
  final String? name;
  final String lastMessage;
  final bool lastIsOutbound;
  final DateTime lastAt;

  String get title => (name ?? '').trim().isNotEmpty ? name!.trim() : '+$phone';

  factory WhatsAppChatSummary.fromJson(Map<String, dynamic> json) {
    return WhatsAppChatSummary(
      phone: json['phone'] as String,
      name: json['name'] as String?,
      lastMessage: (json['lastMessage'] as String?) ?? '',
      lastIsOutbound: json['lastDirection'] == 'outbound',
      lastAt:
          DateTime.tryParse(json['lastAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

class WhatsAppChatMessage {
  WhatsAppChatMessage({
    required this.id,
    required this.isOutbound,
    required this.text,
    this.source,
    required this.sentAt,
    required this.failed,
  });

  final int id;
  final bool isOutbound;
  final String text;

  /// customer, manager, phone (с телефона магазина) или bot.
  final String? source;
  final DateTime sentAt;
  final bool failed;

  factory WhatsAppChatMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppChatMessage(
      id: (json['id'] as num).toInt(),
      isOutbound: json['direction'] == 'outbound',
      text: (json['text'] as String?) ?? '',
      source: json['source'] as String?,
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      failed: json['status'] == 'failed',
    );
  }
}

/// Клиент `/api/whatsapp/web/*`. Магазин определяется сервером по JWT.
class WhatsAppWebService {
  WhatsAppWebService(this._api);

  final ApiClient _api;

  Map<String, dynamic> _map(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  Future<WhatsAppWebStatus> status() async {
    final res = await _api.dio.get('/api/whatsapp/web/status');
    return WhatsAppWebStatus.fromJson(_map(res.data));
  }

  Future<WhatsAppWebStatus> connect() async {
    final res = await _api.dio.post('/api/whatsapp/web/connect');
    return WhatsAppWebStatus.fromJson(_map(res.data));
  }

  Future<WhatsAppWebStatus> logout() async {
    final res = await _api.dio.post('/api/whatsapp/web/logout');
    return WhatsAppWebStatus.fromJson(_map(res.data));
  }

  Future<WhatsAppWebStatus> setBotEnabled(bool enabled) async {
    final res = await _api.dio.patch(
      '/api/whatsapp/web/settings',
      data: {'botEnabled': enabled},
    );
    return WhatsAppWebStatus.fromJson(_map(res.data));
  }

  Future<List<WhatsAppChatSummary>> chats() async {
    final res = await _api.dio.get('/api/whatsapp/web/chats');
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => WhatsAppChatSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<WhatsAppChatMessage>> messages(String phone) async {
    final res = await _api.dio.get(
      '/api/whatsapp/web/chats/$phone/messages',
      queryParameters: {'limit': 100},
    );
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => WhatsAppChatMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> send(String phone, String text) async {
    await _api.dio.post(
      '/api/whatsapp/web/chats/$phone/send',
      data: {'text': text},
    );
  }
}
