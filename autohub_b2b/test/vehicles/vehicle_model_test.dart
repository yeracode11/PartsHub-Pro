import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  int currentMileage = 50000,
  int? nextServiceMileage,
  String? nextServiceDate,
}) => {
  'id': 1,
  'organizationId': 'org',
  'customerId': 7,
  'customer': {'name': 'Иван', 'phone': '+7 700'},
  'brand': 'Toyota',
  'model': 'Camry',
  'year': 2018,
  'plateNumber': '001ABC02',
  'currentMileage': currentMileage,
  'nextServiceMileage': nextServiceMileage,
  'nextServiceDate': nextServiceDate,
};

void main() {
  group('VehicleModel.fromJson', () {
    test('читает владельца и базовые поля', () {
      final v = VehicleModel.fromJson(_json());
      expect(v.customerName, 'Иван');
      expect(v.customerPhone, '+7 700');
      expect(v.displayName, 'Toyota Camry (2018)');
      expect(v.currentMileage, 50000);
    });

    test('без владельца и необязательных полей не падает', () {
      final v = VehicleModel.fromJson({'id': 2});
      expect(v.fuelType, 'petrol');
      expect(v.transmission, 'manual');
      expect(v.fuelTypeDisplay, 'Бензин');
      expect(v.transmissionDisplay, 'Механика');
      expect(v.customerName, 'Неизвестный клиент');
      expect(v.currentMileage, 0);
      expect(v.isActive, isTrue);
      expect(v.needsService, isFalse);
    });
  });

  group('VehicleModel.needsService', () {
    test('false без данных о следующем ТО', () {
      expect(VehicleModel.fromJson(_json()).needsService, isFalse);
    });

    test('true, если дата ТО прошла', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final v = VehicleModel.fromJson(
        _json(nextServiceDate: past.toIso8601String()),
      );
      expect(v.needsService, isTrue);
    });

    test('true, если до ТО осталось не больше 1000 км', () {
      final v = VehicleModel.fromJson(_json(nextServiceMileage: 51000));
      expect(v.needsService, isTrue);
      expect(v.kmUntilService, 1000);
    });

    test('false, если до ТО больше 1000 км и дата впереди', () {
      final future = DateTime.now().add(const Duration(days: 60));
      final v = VehicleModel.fromJson(
        _json(
          nextServiceMileage: 55000,
          nextServiceDate: future.toIso8601String(),
        ),
      );
      expect(v.needsService, isFalse);
      expect(v.daysUntilService, inInclusiveRange(58, 60));
    });
  });
}
