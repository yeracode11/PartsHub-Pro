enum DonorStatus {
  awaiting('awaiting', 'Ждёт разбора'),
  dismantling('dismantling', 'В разборе'),
  dismantled('dismantled', 'Разобран'),
  closed('closed', 'Закрыт');

  const DonorStatus(this.value, this.label);

  final String value;
  final String label;

  static DonorStatus fromValue(String? value) => DonorStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => DonorStatus.awaiting,
  );
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

String? _str(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// Деньги по донору. Приходит только владельцу и менеджеру.
class DonorEconomics {
  final double totalCost;
  final double income;
  final double profit;
  final double soldRevenue;
  final double pendingRevenue;
  final double stockValue;
  final double scrapIncome;
  final double? paybackPercent;
  final bool isPaidBack;
  final double forecastProfit;

  const DonorEconomics({
    required this.totalCost,
    required this.income,
    required this.profit,
    required this.soldRevenue,
    required this.pendingRevenue,
    required this.stockValue,
    required this.scrapIncome,
    required this.paybackPercent,
    required this.isPaidBack,
    required this.forecastProfit,
  });

  factory DonorEconomics.fromJson(Map<String, dynamic> json) => DonorEconomics(
    totalCost: _toDouble(json['totalCost']),
    income: _toDouble(json['income']),
    profit: _toDouble(json['profit']),
    soldRevenue: _toDouble(json['soldRevenue']),
    pendingRevenue: _toDouble(json['pendingRevenue']),
    stockValue: _toDouble(json['stockValue']),
    scrapIncome: _toDouble(json['scrapIncome']),
    paybackPercent: json['paybackPercent'] == null
        ? null
        : _toDouble(json['paybackPercent']),
    isPaidBack: json['isPaidBack'] == true,
    forecastProfit: _toDouble(json['forecastProfit']),
  );
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
  final int? year;
  final String? vin;
  final String? engine;
  final String? color;
  final int? mileage;
  final double? purchasePrice;
  final double? extraCosts;
  final double? scrapIncome;
  final DateTime? purchaseDate;
  final String? source;
  final String? notes;
  final DonorStatus status;
  final int partsCount;
  final int unitsInStock;
  final int unitsSold;
  final DonorEconomics? economics;
  final List<DonorPart> parts;
  final List<String> photos;

  const DonorModel({
    required this.id,
    required this.brand,
    required this.model,
    this.year,
    this.vin,
    this.engine,
    this.color,
    this.mileage,
    this.purchasePrice,
    this.extraCosts,
    this.scrapIncome,
    this.purchaseDate,
    this.source,
    this.notes,
    required this.status,
    required this.partsCount,
    required this.unitsInStock,
    required this.unitsSold,
    this.economics,
    this.parts = const [],
    this.photos = const [],
  });

  String get title => [brand, model, if (year != null) '$year'].join(' ');

  bool get isClosed => status == DonorStatus.closed;

  factory DonorModel.fromJson(Map<String, dynamic> json) {
    final economics = json['economics'] as Map<String, dynamic>?;
    // Без прав на финансы бэкенд отдаёт только складские счётчики.
    final counters =
        economics ?? (json['stock'] as Map<String, dynamic>?) ?? const {};

    return DonorModel(
      id: _toInt(json['id']),
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      year: _toIntOrNull(json['year']),
      vin: _str(json['vin']),
      engine: _str(json['engine']),
      color: _str(json['color']),
      mileage: _toIntOrNull(json['mileage']),
      purchasePrice: json.containsKey('purchasePrice')
          ? _toDouble(json['purchasePrice'])
          : null,
      extraCosts: json.containsKey('extraCosts')
          ? _toDouble(json['extraCosts'])
          : null,
      scrapIncome: json.containsKey('scrapIncome')
          ? _toDouble(json['scrapIncome'])
          : null,
      purchaseDate: DateTime.tryParse(json['purchaseDate']?.toString() ?? ''),
      source: _str(json['source']),
      notes: _str(json['notes']),
      status: DonorStatus.fromValue(json['status'] as String?),
      partsCount: _toInt(counters['partsCount']),
      unitsInStock: _toInt(counters['unitsInStock']),
      unitsSold: _toInt(counters['unitsSold']),
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
