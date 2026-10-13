/// Запись сервисной истории автомобиля (GET /api/vehicles/:id/service-history).
class VehicleServiceRecordModel {
  final int id;
  final DateTime serviceDate;
  final int mileage;
  final String? description;
  final int? orderId;
  final int? nextServiceMileage;
  final DateTime? nextServiceDate;

  const VehicleServiceRecordModel({
    required this.id,
    required this.serviceDate,
    required this.mileage,
    this.description,
    this.orderId,
    this.nextServiceMileage,
    this.nextServiceDate,
  });

  factory VehicleServiceRecordModel.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? value) =>
        value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
    return VehicleServiceRecordModel(
      id: (json['id'] as num).toInt(),
      serviceDate: date(json['serviceDate']) ?? DateTime.now(),
      mileage: (json['mileage'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      orderId: (json['orderId'] as num?)?.toInt(),
      nextServiceMileage: (json['nextServiceMileage'] as num?)?.toInt(),
      nextServiceDate: date(json['nextServiceDate']),
    );
  }
}
