import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:autohub_b2b/models/whatsapp_connection_model.dart';

/// Клиент для Meta WhatsApp Cloud API подключений организации.
///
/// Использует существующий backend `/api/whatsapp/connections`
/// (JWT-аутентификация через [ApiClient]; organizationId и Meta
/// access token — только на сервере, никогда во Flutter).
class MetaWhatsAppService {
  final ApiClient _apiClient;

  MetaWhatsAppService(this._apiClient);

  /// GET /api/whatsapp/connections — подключения текущей организации (из JWT).
  Future<List<WhatsAppConnectionModel>> getConnections() async {
    final response = await _apiClient.dio.get('/api/whatsapp/connections');
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (e) => WhatsAppConnectionModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  /// POST /api/whatsapp/connections — создать подключение для организации
  /// текущего пользователя (organizationId берётся backend'ом из JWT).
  ///
  /// Meta access token НЕ передаётся и НЕ хранится в приложении.
  Future<WhatsAppConnectionModel> createConnection({
    required String phoneNumberId,
    required String wabaId,
    required String displayName,
  }) async {
    final response = await _apiClient.dio.post(
      '/api/whatsapp/connections',
      data: {
        'phoneNumberId': phoneNumberId,
        'wabaId': wabaId,
        'displayName': displayName,
      },
    );
    return WhatsAppConnectionModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
