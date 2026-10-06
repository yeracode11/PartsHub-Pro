enum DonorStatus {
  purchased('purchased', 'Куплен'),
  waitingForDismantling('waiting_for_dismantling', 'Ждёт разбора'),
  dismantling('dismantling', 'В разборе'),
  partiallyDismantled('partially_dismantled', 'Разобран частично'),
  fullyDismantled('fully_dismantled', 'Разобран полностью'),
  archived('archived', 'В архиве');

  const DonorStatus(this.value, this.label);

  final String value;
  final String label;

  /// Как назвать переход в этот статус в меню.
  String get actionLabel => switch (this) {
    DonorStatus.purchased => 'Вернуть в «Куплен»',
    DonorStatus.waitingForDismantling => 'Привезли, ждёт разбора',
    DonorStatus.dismantling => 'В разбор',
    DonorStatus.partiallyDismantled => 'Разобран частично',
    DonorStatus.fullyDismantled => 'Разобран полностью',
    DonorStatus.archived => 'В архив',
  };

  static const _legacy = {
    'awaiting': DonorStatus.waitingForDismantling,
    'dismantled': DonorStatus.fullyDismantled,
    'closed': DonorStatus.archived,
  };

  static DonorStatus? tryParse(String? value) {
    for (final s in DonorStatus.values) {
      if (s.value == value) return s;
    }
    return _legacy[value];
  }

  static DonorStatus fromValue(String? value) =>
      tryParse(value) ?? DonorStatus.purchased;
}

enum DonorTransmission {
  manual('manual', 'Механика'),
  automatic('automatic', 'Автомат'),
  cvt('cvt', 'Вариатор'),
  robot('robot', 'Робот');

  const DonorTransmission(this.value, this.label);

  final String value;
  final String label;

  static DonorTransmission? tryParse(dynamic value) {
    for (final t in DonorTransmission.values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

enum DonorDrivetrain {
  fwd('fwd', 'Передний'),
  rwd('rwd', 'Задний'),
  awd('awd', 'Полный');

  const DonorDrivetrain(this.value, this.label);

  final String value;
  final String label;

  static DonorDrivetrain? tryParse(dynamic value) {
    for (final d in DonorDrivetrain.values) {
      if (d.value == value) return d;
    }
    return null;
  }
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(dynamic v) => v == null ? null : _toInt(v);

double? _toDoubleOrNull(dynamic v) => v == null ? null : _toDouble(v);

DateTime? _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

String? _str(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// Деньги по донору. Приходит только владельцу и менеджеру.
class DonorEconomics {
  /// Покупка плюс доставка, разборка и прочие расходы.
  final double totalCost;
  final double extraCosts;
  final double soldRevenue;
  final double refunds;

  /// Продажи минус возвраты.
  final double realizedRevenue;
  final double scrapIncome;

  /// Фактически вернувшиеся деньги: выручка плюс доход вне склада.
  final double income;
  final double stockValue;
  final double pendingRevenue;

  /// Склад и резерв по цене продажи.
  final double remainingValue;

  /// Часть себестоимости машины, приходящаяся на непроданные детали.
  final double remainingCost;
  final double expectedRevenue;
  final double realizedProfit;
  final double expectedProfit;
  final double? roi;
  final double? expectedRoi;
  final double? paybackPercent;
  final bool isPaidBack;
  final int unitsReceived;
  final int unitsReserved;
  final int unitsWrittenOff;

  const DonorEconomics({
    required this.totalCost,
    required this.extraCosts,
    required this.soldRevenue,
    required this.refunds,
    required this.realizedRevenue,
    required this.scrapIncome,
    required this.income,
    required this.stockValue,
    required this.pendingRevenue,
    required this.remainingValue,
    required this.remainingCost,
    required this.expectedRevenue,
    required this.realizedProfit,
    required this.expectedProfit,
    required this.roi,
    required this.expectedRoi,
    required this.paybackPercent,
    required this.isPaidBack,
    required this.unitsReceived,
    required this.unitsReserved,
    required this.unitsWrittenOff,
  });

  factory DonorEconomics.fromJson(Map<String, dynamic> json) => DonorEconomics(
    totalCost: _toDouble(json['totalCost']),
    extraCosts: _toDouble(json['extraCosts']),
    soldRevenue: _toDouble(json['soldRevenue']),
    refunds: _toDouble(json['refunds']),
    realizedRevenue: _toDouble(json['realizedRevenue']),
    scrapIncome: _toDouble(json['scrapIncome']),
    income: _toDouble(json['income']),
    stockValue: _toDouble(json['stockValue']),
    pendingRevenue: _toDouble(json['pendingRevenue']),
    remainingValue: _toDouble(json['remainingValue']),
    remainingCost: _toDouble(json['remainingCost']),
    expectedRevenue: _toDouble(json['expectedRevenue']),
    realizedProfit: _toDouble(json['realizedProfit']),
    expectedProfit: _toDouble(json['expectedProfit']),
    roi: _toDoubleOrNull(json['roi']),
    expectedRoi: _toDoubleOrNull(json['expectedRoi']),
    paybackPercent: _toDoubleOrNull(json['paybackPercent']),
    isPaidBack: json['isPaidBack'] == true,
    unitsReceived: _toInt(json['unitsReceived']),
    unitsReserved: _toInt(json['unitsReserved']),
    unitsWrittenOff: _toInt(json['unitsWrittenOff']),
  );
}

/// Одна запись журнала: кто и какие деньги или статус поменял.
class DonorHistoryEntry {
  final DateTime createdAt;
  final String? userName;
  final String action;
  final Map<String, ({Object? from, Object? to})> changes;

  const DonorHistoryEntry({
    required this.createdAt,
    required this.userName,
    required this.action,
    required this.changes,
  });

  factory DonorHistoryEntry.fromJson(Map<String, dynamic> json) {
    final raw = json['changes'] as Map<String, dynamic>? ?? const {};
    return DonorHistoryEntry(
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      userName: _str(json['userName']),
      action: json['action']?.toString() ?? 'update',
      changes: {
        for (final entry in raw.entries)
          if (entry.value is Map)
            entry.key: (
              from: (entry.value as Map)['from'],
              to: (entry.value as Map)['to'],
            ),
      },
    );
  }
}

class DonorPart {
  final int id;
  final String name;
  final String? category;
  final double price;
  final int quantity;
  final String? warehouseCell;
  final int soldQuantity;
  final double soldRevenue;

  /// Доля вложений в машину на одну штуку — минимальная цена без убытка.
  /// Только для владельца и менеджера.
  final double? unitCost;

  /// Выручка с проданных штук минус их себестоимость.
  final double? realizedProfit;

  const DonorPart({
    required this.id,
    required this.name,
    this.category,
    required this.price,
    required this.quantity,
    this.warehouseCell,
    required this.soldQuantity,
    required this.soldRevenue,
    this.unitCost,
    this.realizedProfit,
  });

  factory DonorPart.fromJson(Map<String, dynamic> json) => DonorPart(
    id: _toInt(json['id']),
    name: json['name']?.toString() ?? '',
    category: _str(json['category']),
    price: _toDouble(json['price']),
    quantity: _toInt(json['quantity']),
    warehouseCell: _str(json['warehouseCell']),
    soldQuantity: _toInt(json['soldQuantity']),
    soldRevenue: _toDouble(json['soldRevenue']),
    unitCost: json['unitCost'] == null ? null : _toDouble(json['unitCost']),
    realizedProfit: json['realizedProfit'] == null
        ? null
        : _toDouble(json['realizedProfit']),
  );
}

class DonorModel {
  final int id;
  final String brand;
  final String model;
  final String? generation;
  final String? body;
  final int? year;
  final String? vin;
  final String? engine;
  final double? engineVolume;
  final DonorTransmission? transmission;
  final DonorDrivetrain? drivetrain;
  final String? color;
  final int? mileage;

  /// Деньги приходят только владельцу и менеджеру, иначе null.
  final double? purchasePrice;
  final double? deliveryCost;
  final double? dismantlingCost;
  final double? otherCosts;
  final double? scrapIncome;
  final DateTime? purchaseDate;
  final DateTime? dismantlingStartDate;
  final DateTime? dismantlingEndDate;
  final String? source;
  final String? notes;
  final DonorStatus status;

  /// Куда можно перевести донора — правила живут на сервере.
  final List<DonorStatus> allowedStatuses;
  final int partsCount;
  final int unitsInStock;
  final int unitsSold;
  final int unitsReserved;
  final DonorEconomics? economics;
  final List<DonorPart> parts;
  final List<String> photos;

  const DonorModel({
    required this.id,
    required this.brand,
    required this.model,
    this.generation,
    this.body,
    this.year,
    this.vin,
    this.engine,
    this.engineVolume,
    this.transmission,
    this.drivetrain,
    this.color,
    this.mileage,
    this.purchasePrice,
    this.deliveryCost,
    this.dismantlingCost,
    this.otherCosts,
    this.scrapIncome,
    this.purchaseDate,
    this.dismantlingStartDate,
    this.dismantlingEndDate,
    this.source,
    this.notes,
    required this.status,
    this.allowedStatuses = const [],
    required this.partsCount,
    required this.unitsInStock,
    required this.unitsSold,
    this.unitsReserved = 0,
    this.economics,
    this.parts = const [],
    this.photos = const [],
  });

  String get title => [
    brand,
    model,
    if (generation != null) generation!,
    if (year != null) '$year',
  ].join(' ');

  bool get isArchived => status == DonorStatus.archived;

  /// Двигатель одной строкой: «2AR-FE 2.5 л».
  String? get engineLabel {
    final parts = [
      if (engine != null) engine!,
      if (engineVolume != null) '${engineVolume!.toStringAsFixed(1)} л',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  double get extraCostsTotal =>
      (deliveryCost ?? 0) + (dismantlingCost ?? 0) + (otherCosts ?? 0);

  factory DonorModel.fromJson(Map<String, dynamic> json) {
    final economics = json['economics'] as Map<String, dynamic>?;
    // Без прав на финансы бэкенд отдаёт только складские счётчики.
    final counters =
        economics ?? (json['stock'] as Map<String, dynamic>?) ?? const {};

    return DonorModel(
      id: _toInt(json['id']),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      generation: _str(json['generation']),
      body: _str(json['body']),
      year: _toIntOrNull(json['year']),
      vin: _str(json['vin']),
      engine: _str(json['engine']),
      engineVolume: _toDoubleOrNull(json['engineVolume']),
      transmission: DonorTransmission.tryParse(json['transmission']),
      drivetrain: DonorDrivetrain.tryParse(json['drivetrain']),
      color: _str(json['color']),
      mileage: _toIntOrNull(json['mileage']),
      purchasePrice: _toDoubleOrNull(json['purchasePrice']),
      deliveryCost: _toDoubleOrNull(json['deliveryCost']),
      dismantlingCost: _toDoubleOrNull(json['dismantlingCost']),
      otherCosts: _toDoubleOrNull(json['otherCosts']),
      scrapIncome: _toDoubleOrNull(json['scrapIncome']),
      purchaseDate: _date(json['purchaseDate']),
      dismantlingStartDate: _date(json['dismantlingStartDate']),
      dismantlingEndDate: _date(json['dismantlingEndDate']),
      source: _str(json['source']),
      notes: _str(json['notes']),
      status: DonorStatus.fromValue(json['status'] as String?),
      allowedStatuses: (json['allowedStatuses'] as List<dynamic>? ?? const [])
          .map((v) => DonorStatus.tryParse(v?.toString()))
          .whereType<DonorStatus>()
          .toList(),
      partsCount: _toInt(counters['partsCount']),
      unitsInStock: _toInt(counters['unitsInStock']),
      unitsSold: _toInt(counters['unitsSold']),
      unitsReserved: _toInt(counters['unitsReserved']),
      economics: economics == null ? null : DonorEconomics.fromJson(economics),
      parts: (json['parts'] as List<dynamic>? ?? const [])
          .map((p) => DonorPart.fromJson(p as Map<String, dynamic>))
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((p) => p.toString())
          .toList(),
    );
  }
}
