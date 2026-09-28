/// Публичная (без accessToken) модель Meta WhatsApp подключения.
/// Соответствует WhatsAppConnectionPublic на backend
/// (Omit<WhatsAppConnection, 'accessToken'>).
class WhatsAppConnectionModel {
  final String id;
  final String organizationId;
  final String phoneNumberId;
  final String? wabaId;
  final String? phoneNumber;
  final String? displayName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WhatsAppConnectionModel({
    required this.id,
    required this.organizationId,
    required this.phoneNumberId,
    this.wabaId,
    this.phoneNumber,
    this.displayName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory WhatsAppConnectionModel.fromJson(Map<String, dynamic> json) {
    return WhatsAppConnectionModel(
      id: json['id']?.toString() ?? '',
      organizationId: json['organizationId']?.toString() ?? '',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      wabaId: json['wabaId']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      displayName: json['displayName']?.toString(),
      status: json['status']?.toString() ?? 'active',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
