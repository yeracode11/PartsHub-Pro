import 'package:autohub_b2b/models/donor_model.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('владелец получает экономику донора', () {
    final donor = DonorModel.fromJson({
      'id': 7,
      'brand': 'Toyota',
      'model': 'Camry',
      'generation': 'XV50',
      'year': 2015,
      'vin': '',
      'engine': '2AR-FE',
      'engineVolume': 2.5,
      'transmission': 'automatic',
      'drivetrain': 'fwd',
      'purchasePrice': '900000.00',
      'deliveryCost': '60000.00',
      'dismantlingCost': '40000.00',
      'otherCosts': '0.00',
      'scrapIncome': '0.00',
      'status': 'dismantling',
      'dismantlingStartDate': '2026-09-01',
      'allowedStatuses': [
        'partially_dismantled',
        'fully_dismantled',
        'archived',
      ],
      'photos': ['/uploads/items/a.jpg'],
      'parts': [
        {
          'id': 1,
          'name': 'Двигатель',
          'price': '300000.00',
          'quantity': 0,
          'soldQuantity': 1,
          'soldRevenue': 280000,
          'unitCost': 150000,
          'realizedProfit': 130000,
        },
      ],
      'economics': {
        'totalCost': 1000000,
        'extraCosts': 100000,
        'soldRevenue': 400000,
        'refunds': 0,
        'realizedRevenue': 400000,
        'scrapIncome': 0,
        'income': 400000,
        'stockValue': 150000,
        'pendingRevenue': 50000,
        'remainingValue': 200000,
        'remainingCost': 333333.33,
        'expectedRevenue': 600000,
        'realizedProfit': -600000,
        'expectedProfit': -400000,
        'roi': -60,
        'expectedRoi': -40,
        'paybackPercent': 40,
        'isPaidBack': false,
        'partsCount': 3,
        'unitsReceived': 4,
        'unitsInStock': 2,
        'unitsSold': 1,
        'unitsReserved': 1,
        'unitsWrittenOff': 0,
      },
    });

    expect(donor.title, 'Toyota Camry XV50 2015');
    expect(donor.vin, isNull);
    expect(donor.engineLabel, '2AR-FE 2.5 л');
    expect(donor.transmission, DonorTransmission.automatic);
    expect(donor.drivetrain, DonorDrivetrain.fwd);
    expect(donor.status, DonorStatus.dismantling);
    expect(donor.allowedStatuses, [
      DonorStatus.partiallyDismantled,
      DonorStatus.fullyDismantled,
      DonorStatus.archived,
    ]);
    expect(donor.dismantlingStartDate, DateTime(2026, 9, 1));
    expect(donor.purchasePrice, 900000);
    expect(donor.extraCostsTotal, 100000);
    expect(donor.economics!.paybackPercent, 40);
    expect(donor.economics!.roi, -60);
    expect(donor.economics!.expectedRevenue, 600000);
    expect(donor.economics!.unitsReceived, 4);
    expect(donor.unitsReserved, 1);
    expect(donor.partsCount, 3);
    expect(donor.photos, ['/uploads/items/a.jpg']);
    expect(donor.parts.single.unitCost, 150000);
    expect(donor.parts.single.realizedProfit, 130000);
  });

  test('кладовщик получает только складские счётчики', () {
    final donor = DonorModel.fromJson({
      'id': 7,
      'brand': 'Nissan',
      'model': 'Teana',
      'status': 'awaiting',
      'stock': {'partsCount': 5, 'unitsInStock': 4, 'unitsSold': 1},
      'parts': [
        {'id': 1, 'name': 'Фара', 'price': 50000, 'quantity': 1},
      ],
    });

    expect(donor.status, DonorStatus.waitingForDismantling);
    expect(donor.economics, isNull);
    expect(donor.purchasePrice, isNull);
    expect(donor.deliveryCost, isNull);
    expect(donor.partsCount, 5);
    expect(donor.unitsInStock, 4);
    expect(donor.parts.single.unitCost, isNull);
    expect(donor.photos, isEmpty);
  });

  test('деталь знает, с какого донора снята', () {
    final item = ItemModel.fromJson({
      'id': 3,
      'name': 'Фара',
      'price': '50000.00',
      'quantity': 1,
      'donorId': 7,
      'donor': {
        'id': 7,
        'brand': 'Toyota',
        'model': 'Camry',
        'generation': 'XV50',
        'year': 2015,
      },
    });

    expect(item.donorId, 7);
    expect(item.donorTitle, 'Toyota Camry XV50 2015');
    expect(ItemModel.fromJson({'id': 4, 'name': 'Дверь'}).donorId, isNull);
  });

  test('запись журнала разбирает изменения «было → стало»', () {
    final entry = DonorHistoryEntry.fromJson({
      'id': '1',
      'action': 'update',
      'createdAt': '2026-10-06T10:00:00.000Z',
      'userName': 'Алия',
      'changes': {
        'purchasePrice': {'from': 900000, 'to': 950000},
        'status': {'from': 'purchased', 'to': 'dismantling'},
      },
    });

    expect(entry.userName, 'Алия');
    expect(entry.changes['purchasePrice']!.to, 950000);
    expect(entry.changes['status']!.from, 'purchased');
  });

  test('OEM без разделителей совпадает, аналоги ищутся тоже', () {
    expect(normalizeOem('04465-12345'), '0446512345');
    expect(normalizeOem('04465 12345'), '0446512345');
    expect(normalizeOem('А2С-53'), 'A2C53');

    final item = ItemModel.fromJson({
      'id': 1,
      'name': 'Колодки',
      'oem': '04465-12345',
      'barcode': '460001',
      'purchaseCost': '1500.00',
      'status': 'active',
      'crossReferences': [
        {'oem': 'GDB3456', 'type': 'aftermarket', 'brand': 'TRW'},
      ],
      'compatibility': [
        {
          'make': 'Toyota',
          'model': 'Camry',
          'generation': 'XV70',
          'yearFrom': 2018,
          'yearTo': 2024,
        },
      ],
    });

    expect(item.matchesQuery('04465 12345'), isTrue);
    expect(item.matchesQuery('gdb3456'), isTrue);
    expect(item.matchesQuery('460001'), isTrue);
    expect(item.purchaseCost, 1500);
    expect(item.compatibility!.single.title, 'Toyota Camry XV70 2018–2024');
  });
}
