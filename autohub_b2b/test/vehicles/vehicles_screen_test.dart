import 'dart:convert';
import 'dart:typed_data';

import 'package:autohub_b2b/screens/vehicles/vehicles_screen.dart';
import 'package:autohub_b2b/services/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:autohub_b2b/models/vehicle_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Отдаёт заранее заданные ответы вместо реальной сети.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function() respond;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return respond();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

Map<String, dynamic> _vehicle(int id, String brand, String plate) => {
  'id': id,
  'customerId': 1,
  'customer': {'name': 'Иван'},
  'brand': brand,
  'model': 'X',
  'year': 2020,
  'plateNumber': plate,
  'currentMileage': 12000,
};

List<Map<String, dynamic>> _many(int from, int count) => [
  for (var i = from; i < from + count; i++) _vehicle(i, 'Brand$i', 'P$i'),
];

Future<_FakeAdapter> _pump(
  WidgetTester tester,
  ResponseBody Function() respond,
) async {
  final adapter = _FakeAdapter(respond);
  final dio = ApiClient().dio;
  // Перехватчики ходят в SecureStorage (платформенный канал) — в тесте не нужны.
  dio.interceptors.clear();
  dio.httpClientAdapter = adapter;
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: VehiclesScreen()));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  group('vehicleServiceLabel', () {
    final now = DateTime(2026, 10, 19, 15);
    VehicleModel car({int? nextKm, DateTime? nextDate}) =>
        VehicleModel.fromJson({
          'id': 1,
          'currentMileage': 50000,
          'nextServiceMileage': nextKm,
          'nextServiceDate': nextDate?.toIso8601String(),
        });

    test('нет данных о ТО', () {
      expect(vehicleServiceLabel(car(), now: now), isNull);
    });

    test('оставшиеся км и дни', () {
      final label = vehicleServiceLabel(
        car(nextKm: 54000, nextDate: DateTime(2026, 12, 3)),
        now: now,
      );
      expect(label, 'ТО через 4\u00a0000 км или 45 дн.');
    });

    test('только км', () {
      expect(
        vehicleServiceLabel(car(nextKm: 50500), now: now),
        'ТО через 500 км',
      );
    });

    test('просрочено по дате и по пробегу', () {
      expect(
        vehicleServiceLabel(car(nextDate: DateTime(2026, 10, 16)), now: now),
        'ТО просрочено на 3 дн.',
      );
      expect(
        vehicleServiceLabel(car(nextKm: 49000), now: now),
        'ТО просрочено на 1\u00a0000 км',
      );
    });

    test('срок наступает сегодня', () {
      expect(
        vehicleServiceLabel(car(nextDate: DateTime(2026, 10, 19)), now: now),
        'ТО сегодня',
      );
    });
  });

  testWidgets('показывает автомобили и фильтрует по госномеру', (tester) async {
    await _pump(
      tester,
      () => _json([
        _vehicle(1, 'Toyota', '001ABC'),
        _vehicle(2, 'Kia', '777XYZ'),
      ], 200),
    );

    expect(find.textContaining('Toyota X'), findsOneWidget);
    expect(find.textContaining('Kia X'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '777');
    await tester.pump();

    expect(find.textContaining('Toyota X'), findsNothing);
    expect(find.textContaining('Kia X'), findsOneWidget);
  });

  testWidgets('пустой список: сообщение и кнопка «Добавить»', (tester) async {
    await _pump(tester, () => _json([], 200));

    expect(find.text('Нет автомобилей'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Добавить'), findsOneWidget);
  });

  testWidgets(
    'ошибка сервера: экран ошибки с «Повторить», а не пустой список',
    (tester) async {
      final adapter = await _pump(
        tester,
        () => _json({'message': 'boom'}, 500),
      );

      expect(find.text('Нет автомобилей'), findsNothing);
      expect(find.text('Повторить'), findsOneWidget);

      final before = adapter.calls;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      expect(adapter.calls, greaterThan(before));
    },
  );

  testWidgets('«Показать ещё» догружает следующую страницу по offset', (
    tester,
  ) async {
    final offsets = <Object?>[];
    // Ответ зависит от offset запроса, поэтому читаем его из адаптера.
    final paged = _PagedAdapter((options) {
      offsets.add(options.queryParameters['offset']);
      final offset = options.queryParameters['offset'] as int;
      return _json(offset == 0 ? _many(0, 50) : _many(50, 3), 200);
    });

    final dio = ApiClient().dio;
    dio.interceptors.clear();
    dio.httpClientAdapter = paged;
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: VehiclesScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Показать ещё'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Показать ещё'));
    await tester.pumpAndSettle();

    expect(offsets, [0, 50]);
    await tester.scrollUntilVisible(
      find.textContaining('Brand52 X'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Показать ещё'), findsNothing);
  });

  testWidgets('поиск уходит на сервер параметром q с задержкой', (
    tester,
  ) async {
    final queries = <Object?>[];
    final dio = ApiClient().dio;
    dio.interceptors.clear();
    dio.httpClientAdapter = _PagedAdapter((options) {
      queries.add(options.queryParameters['q']);
      return _json([_vehicle(1, 'Toyota', '001ABC')], 200);
    });
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: VehiclesScreen()));
    await tester.pumpAndSettle();
    expect(queries, [null]);

    await tester.enterText(find.byType(TextField), 'toy');
    await tester.pump(const Duration(milliseconds: 100));
    expect(queries, [null]); // дебаунс: запроса ещё нет
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(queries, [null, 'toy']);
  });
}

/// Адаптер, которому нужны параметры запроса для формирования ответа.
class _PagedAdapter implements HttpClientAdapter {
  _PagedAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}
