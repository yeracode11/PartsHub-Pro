import 'package:autohub_b2b/models/donor_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('владелец получает экономику донора', () {
    final donor = DonorModel.fromJson({
      'id': 7,
      'brand': 'Toyota',
      'model': 'Camry',
      'year': 2015,
      'vin': '',
      'purchasePrice': '900000.00',
      'extraCosts': '100000.00',
      'scrapIncome': '0.00',
      'status': 'dismantling',
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
        'income': 400000,
        'profit': -600000,
        'soldRevenue': 400000,
        'pendingRevenue': 0,
        'stockValue': 150000,
        'scrapIncome': 0,
        'paybackPercent': 40,
        'isPaidBack': false,
        'forecastProfit': -450000,
        'partsCount': 3,
        'unitsInStock': 2,
        'unitsSold': 1,
      },
    });

    expect(donor.title, 'Toyota Camry 2015');
    expect(donor.vin, isNull);
    expect(donor.status, DonorStatus.dismantling);
    expect(donor.purchasePrice, 900000);
    expect(donor.economics!.paybackPercent, 40);
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

    expect(donor.economics, isNull);
    expect(donor.purchasePrice, isNull);
    expect(donor.partsCount, 5);
    expect(donor.unitsInStock, 4);
    expect(donor.parts.single.unitCost, isNull);
    expect(donor.photos, isEmpty);
  });
}
