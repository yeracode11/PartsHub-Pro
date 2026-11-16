import 'package:dio/dio.dart';

import 'package:autohub_b2b/config/environment.dart';

/// Для чего подтверждаем номер.
enum WhatsAppVerificationPurpose {
  register('register'),
  login('login'),
  resetPassword('reset_password');

  const WhatsAppVerificationPurpose(this.apiValue);
  final String apiValue;
}

/// Запрос подтверждения: код, который пользователь отправит боту Vinly.
class WhatsAppVerificationTicket {
  const WhatsAppVerificationTicket({
    required this.verificationId,
    required this.secret,
    required this.code,
    required this.botPhone,
    required this.waLink,
    required this.expiresAt,
  });

  factory WhatsAppVerificationTicket.fromJson(Map<String, dynamic> json) {
    return WhatsAppVerificationTicket(
      verificationId: json['verificationId'] as String,
      secret: json['secret'] as String,
      code: json['code'] as String,
      botPhone: json['botPhone'] as String,
      waLink: json['waLink'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
    );
  }

  final String verificationId;
  final String secret;
  final String code;

  /// Номер бота цифрами, без «+».
  final String botPhone;
  final String waLink;
  final DateTime expiresAt;
}

enum WhatsAppVerificationState { pending, verified, consumed, expired }

class WhatsAppVerificationStatus {
  const WhatsAppVerificationStatus(this.state, {this.verificationToken});

  final WhatsAppVerificationState state;

  /// Есть только у [WhatsAppVerificationState.verified].
  final String? verificationToken;
}

/// Бесплатное подтверждение номера: пользователь сам пишет код боту в WhatsApp,
/// сервер сверяет номер отправителя. Платные SMS и шаблоны Meta не нужны.
class WhatsAppVerificationService {
  WhatsAppVerificationService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: Environment.apiBaseUrl.replaceAll('/api', ''),
                connectTimeout: Environment.connectTimeout,
                receiveTimeout: Environment.receiveTimeout,
                sendTimeout: Environment.receiveTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  Future<WhatsAppVerificationTicket> start({
    required String phone,
    required WhatsAppVerificationPurpose purpose,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/whatsapp/start',
      data: {'phone': phone, 'purpose': purpose.apiValue},
    );
    return WhatsAppVerificationTicket.fromJson(response.data!);
  }

  Future<WhatsAppVerificationStatus> status(
    WhatsAppVerificationTicket ticket,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/whatsapp/status',
      data: {
        'verificationId': ticket.verificationId,
        'secret': ticket.secret,
      },
    );
    final data = response.data!;
    final state = switch (data['status']) {
      'verified' => WhatsAppVerificationState.verified,
      'consumed' => WhatsAppVerificationState.consumed,
      'expired' => WhatsAppVerificationState.expired,
      _ => WhatsAppVerificationState.pending,
    };
    return WhatsAppVerificationStatus(
      state,
      verificationToken: data['verificationToken'] as String?,
    );
  }
}
