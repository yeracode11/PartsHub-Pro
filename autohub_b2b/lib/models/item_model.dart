import 'package:equatable/equatable.dart';

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _int(dynamic value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

double? _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

/// Другой номер, под которым ищут эту деталь.
class ItemCrossReference extends Equatable {
  final String oem;
  final String? brand;

  /// alternative — другой оригинальный номер, aftermarket — неоригинальный аналог.
  final String type;

  const ItemCrossReference({
    required this.oem,
    this.brand,
    this.type = 'alternative',
  });

  bool get isAftermarket => type == 'aftermarket';

  factory ItemCrossReference.fromJson(Map<String, dynamic> json) =>
      ItemCrossReference(
        oem: json['oem']?.toString() ?? '',
        brand: _text(json['brand']),
        type: json['type'] == 'aftermarket' ? 'aftermarket' : 'alternative',
      );

  Map<String, dynamic> toJson() => {'oem': oem, 'brand': brand, 'type': type};

  @override
  List<Object?> get props => [oem, brand, type];
}

/// Машина, на которую подходит деталь.
class ItemCompatibility extends Equatable {
  final String make;
  final String model;
  final String? generation;
  final int? yearFrom;
  final int? yearTo;
  final String? body;
  final String? engine;
  final String? transmission;

  const ItemCompatibility({
    required this.make,
    required this.model,
    this.generation,
    this.yearFrom,
    this.yearTo,
    this.body,
    this.engine,
    this.transmission,
  });

  /// «Toyota Camry XV70 2018–2024»
  String get title {
    final years = yearFrom == null && yearTo == null
        ? null
        : yearFrom == yearTo
        ? '$yearFrom'
        : '${yearFrom ?? '…'}–${yearTo ?? '…'}';
    return [make, model, generation, years].whereType<String>().join(' ');
  }

  /// «кузов ACV40 · 2.5 · автомат»
  String? get details {
    final parts = [body, engine, transmission].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory ItemCompatibility.fromJson(Map<String, dynamic> json) =>
      ItemCompatibility(
        make: json['make']?.toString() ?? '',
        model: json['model']?.toString() ?? '',
        generation: _text(json['generation']),
        yearFrom: _int(json['yearFrom']),
        yearTo: _int(json['yearTo']),
        body: _text(json['body']),
        engine: _text(json['engine']),
        transmission: _text(json['transmission']),
      );

  Map<String, dynamic> toJson() => {
    'make': make,
    'model': model,
    'generation': generation,
    'yearFrom': yearFrom,
    'yearTo': yearTo,
    'body': body,
    'engine': engine,
    'transmission': transmission,
  };

  @override
  List<Object?> get props => [
    make,
    model,
    generation,
    yearFrom,
    yearTo,
    body,
    engine,
    transmission,
  ];
}

const _oemLookalikes = {
  'А': 'A',
  'В': 'B',
  'Е': 'E',
  'К': 'K',
  'М': 'M',
  'Н': 'H',
  'О': 'O',
  'Р': 'P',
  'С': 'C',
  'Т': 'T',
  'У': 'Y',
  'Х': 'X',
};

/// Как на сервере: «04465-12345», «0446512345» и «04465 12345» совпадают.
String normalizeOem(String value) => value
    .toUpperCase()
    .split('')
    .map((char) => _oemLookalikes[char] ?? char)
    .join()
    .replaceAll(RegExp('[^A-Z0-9]'), '');

/// Страница склада с сервера.
class ItemsPage {
  final List<ItemModel> items;
  final int total;

  const ItemsPage({required this.items, required this.total});
}

class ItemModel extends Equatable {
  final int? id;
  final String name;
  final String? category;
  final String? sku;
  final double price;
  final int quantity;
  final int reservedQuantity;
  final String condition;
  final String? description;
  final String? imageUrl;
  final List<String>? images;
  final String? warehouseCell;
  final String? warehouseId;
  final String? oem;
  final String? brand;
  final String? barcode;
  final String? internalCode;

  /// Только для владельца и менеджера, иначе null.
  final double? purchaseCost;

  /// active или archived (снят с продажи).
  final String status;

  /// null — карточка загружена списком, без аналогов и применимости.
  final List<ItemCrossReference>? crossReferences;
  final List<ItemCompatibility>? compatibility;

  /// С какой машины-донора снята деталь.
  final int? donorId;
  final String? donorTitle;
  final bool synced;
  final DateTime createdAt;
  final DateTime updatedAt;

  ItemModel({
    this.id,
    required this.name,
    this.category,
    this.sku,
    required this.price,
    required this.quantity,
    this.reservedQuantity = 0,
    required this.condition,
    this.description,
    this.imageUrl,
    this.images,
    this.warehouseCell,
    this.warehouseId,
    this.oem,
    this.brand,
    this.barcode,
    this.internalCode,
    this.purchaseCost,
    this.status = 'active',
    this.crossReferences,
    this.compatibility,
    this.donorId,
    this.donorTitle,
    this.synced = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isArchived => status == 'archived';

  /// Сколько можно продать: остаток минус резерв.
  int get available => quantity - reservedQuantity;

  /// Совпадает ли деталь с запросом без сервера (офлайн-кэш).
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final normalized = normalizeOem(q);
    bool has(String? value) => value?.toLowerCase().contains(q) ?? false;
    return has(name) ||
        has(sku) ||
        has(brand) ||
        barcode?.toLowerCase() == q ||
        internalCode?.toLowerCase() == q ||
        (normalized.isNotEmpty &&
            (normalizeOem(oem ?? '').contains(normalized) ||
                (crossReferences ?? const []).any(
                  (r) => normalizeOem(r.oem).contains(normalized),
                )));
  }

  ItemModel copyWith({
    int? id,
    String? name,
    String? category,
    String? sku,
    double? price,
    int? quantity,
    String? condition,
    String? description,
    String? imageUrl,
    List<String>? images,
    String? warehouseCell,
    String? warehouseId,
    bool? synced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity,
      condition: condition ?? this.condition,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      warehouseCell: warehouseCell ?? this.warehouseCell,
      warehouseId: warehouseId ?? this.warehouseId,
      oem: oem,
      brand: brand,
      barcode: barcode,
      internalCode: internalCode,
      purchaseCost: purchaseCost,
      status: status,
      crossReferences: crossReferences,
      compatibility: compatibility,
      donorId: donorId,
      donorTitle: donorTitle,
      synced: synced ?? this.synced,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'sku': sku,
      'price': price,
      'quantity': quantity,
      'reservedQuantity': reservedQuantity,
      'condition': condition,
      'description': description,
      'imageUrl': imageUrl,
      'images': images,
      'warehouseCell': warehouseCell,
      'warehouseId': warehouseId,
      'oem': oem,
      'brand': brand,
      'barcode': barcode,
      'internalCode': internalCode,
      if (purchaseCost != null) 'purchaseCost': purchaseCost,
      'status': status,
      if (crossReferences != null)
        'crossReferences': crossReferences!.map((r) => r.toJson()).toList(),
      if (compatibility != null)
        'compatibility': compatibility!.map((c) => c.toJson()).toList(),
      'donorId': donorId,
      if (donorTitle != null) 'donorTitle': donorTitle,
      'synced': synced,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    try {
      // Обработка price (может быть string из PostgreSQL decimal)
      final priceValue = json['price'];
      final double price;
      if (priceValue is String) {
        price = double.tryParse(priceValue) ?? 0.0;
      } else if (priceValue is num) {
        price = priceValue.toDouble();
      } else {
        price = 0.0;
      }

      // Обработка дат
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        if (dateValue is DateTime) return dateValue;
        if (dateValue is String) {
          try {
            return DateTime.parse(dateValue);
          } catch (e) {
            return null;
          }
        }
        return null;
      }

      return ItemModel(
        id: json['id'] is int
            ? json['id']
            : (json['id'] is String ? int.tryParse(json['id']) : null),
        name: json['name'] as String? ?? 'Без названия',
        category: json['category'] as String?,
        sku: json['sku'] as String?,
        price: price,
        quantity: json['quantity'] is int
            ? json['quantity']
            : (json['quantity'] is num ? json['quantity'].toInt() : 0),
        reservedQuantity: json['reservedQuantity'] is int
            ? json['reservedQuantity']
            : (json['reservedQuantity'] is num
                  ? json['reservedQuantity'].toInt()
                  : 0),
        condition: json['condition'] as String? ?? 'new',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        images: json['images'] != null
            ? (json['images'] is List
                  ? List<String>.from(json['images'].map((e) => e.toString()))
                  : null)
            : null,
        warehouseCell: json['warehouseCell'] as String?,
        warehouseId: json['warehouseId'] as String?,
        oem: _text(json['oem']),
        brand: _text(json['brand']),
        barcode: _text(json['barcode']),
        internalCode: _text(json['internalCode']),
        purchaseCost: _double(json['purchaseCost']),
        status: json['status'] == 'archived' ? 'archived' : 'active',
        crossReferences: (json['crossReferences'] as List<dynamic>?)
            ?.map((r) => ItemCrossReference.fromJson(r as Map<String, dynamic>))
            .toList(),
        compatibility: (json['compatibility'] as List<dynamic>?)
            ?.map((c) => ItemCompatibility.fromJson(c as Map<String, dynamic>))
            .toList(),
        donorId: _donorId(json),
        donorTitle: _donorTitle(json),
        synced: json['synced'] is bool ? json['synced'] : false,
        createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
        updatedAt: parseDate(json['updatedAt']) ?? DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    sku,
    price,
    quantity,
    reservedQuantity,
    condition,
    description,
    imageUrl,
    images,
    warehouseCell,
    warehouseId,
    oem,
    brand,
    barcode,
    internalCode,
    purchaseCost,
    status,
    crossReferences,
    compatibility,
    donorId,
    donorTitle,
    synced,
    createdAt,
    updatedAt,
  ];
}

int? _donorId(Map<String, dynamic> json) {
  final donor = json['donor'];
  final raw = donor is Map ? donor['id'] : json['donorId'];
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '');
}

String? _donorTitle(Map<String, dynamic> json) {
  final donor = json['donor'];
  if (donor is! Map) return json['donorTitle'] as String?;
  final title = [
    donor['brand'],
    donor['model'],
    donor['generation'],
    donor['year'],
  ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' ');
  return title.isEmpty ? null : title;
}
