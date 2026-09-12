import 'package:flutter/foundation.dart';

import 'package:autohub_b2b/models/item_model.dart';

/// Разбор QR с этикетки [LabelProductData.fromItem]: `SKU:…|ID:n|CELL:…`.
@immutable
class LabelQrPayload {
  const LabelQrPayload({
    this.id,
    this.sku,
    required this.raw,
  });

  final int? id;
  final String? sku;
  final String raw;

  factory LabelQrPayload.parse(String code) {
    final raw = code.trim();
    if (raw.isEmpty) {
      return LabelQrPayload(raw: raw);
    }
    final plainId = int.tryParse(raw);
    if (plainId != null && plainId > 0) {
      return LabelQrPayload(id: plainId, raw: raw);
    }
    final upper = raw.toUpperCase();
    if (!upper.contains('ID:') && !upper.contains('SKU:')) {
      return LabelQrPayload(raw: raw);
    }
    int? id;
    String? sku;
    for (final part in raw.split('|')) {
      final s = part.trim();
      final colon = s.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      final key = s.substring(0, colon).trim().toUpperCase();
      final val = s.substring(colon + 1).trim();
      if (key == 'ID') {
        id = int.tryParse(val);
      } else if (key == 'SKU' && val.isNotEmpty) {
        sku = val;
      }
    }
    return LabelQrPayload(id: id, sku: sku, raw: raw);
  }
}

/// Данные для термоэтикетки (склад / WMS).
@immutable
class LabelProductData {
  const LabelProductData({
    required this.productName,
    required this.sku,
    this.price,
    this.currencySymbol = '₸',
    this.showPrice = true,
    this.showBarcode = true,
    this.showQr = true,
    this.showWarehouseCell = true,
    this.qrPayload,
    /// Явное значение для CODE128 (только печатаемый ASCII 32–126). Если null — из [sku].
    this.barcodeData,
    this.logoAssetPath = 'assets/icons/auto-plus-logo.png',
    this.warehouseCell,
  });

  final String productName;
  final String sku;
  final double? price;
  final String currencySymbol;
  final bool showPrice;
  final bool showBarcode;
  final bool showQr;
  /// Показывать строку «Ячейка» при наличии [warehouseCell].
  final bool showWarehouseCell;
  /// Текст в QR (по умолчанию SKU или комбинация).
  final String? qrPayload;
  final String? barcodeData;
  /// Пустая строка — без логотипа.
  final String logoAssetPath;
  final String? warehouseCell;

  /// Этикетка из карточки товара (склад / WMS).
  factory LabelProductData.fromItem(ItemModel item) {
    final rawSku = item.sku?.trim();
    final skuForBarcode = (rawSku != null && rawSku.isNotEmpty)
        ? rawSku
        : 'ID${item.id ?? 0}';

    final qr = <String>[
      if (rawSku != null && rawSku.isNotEmpty) 'SKU:$rawSku',
      'ID:${item.id}',
      if (item.warehouseCell != null && item.warehouseCell!.trim().isNotEmpty)
        'CELL:${item.warehouseCell!.trim()}',
    ].join('|');

    String? cell;
    final w = item.warehouseCell?.trim();
    if (w != null && w.isNotEmpty) cell = w;

    return LabelProductData(
      productName: item.name.trim().isEmpty ? '—' : item.name.trim(),
      sku: skuForBarcode,
      price: item.price,
      warehouseCell: cell,
      qrPayload: qr,
      showPrice: true,
      showBarcode: true,
      showQr: true,
      showWarehouseCell: true,
    );
  }

  /// CODE128 в пакете `barcode` ожидает ASCII; нелатиница → запасной код.
  String get effectiveBarcodeAscii {
    final raw = (barcodeData ?? sku).trim();
    if (raw.isEmpty) return '0';
    final buf = StringBuffer();
    for (final c in raw.codeUnits) {
      if (c >= 32 && c <= 126) buf.writeCharCode(c);
    }
    final s = buf.toString();
    if (s.isEmpty) return 'X${sku.hashCode.abs()}';
    return s.length > 48 ? s.substring(0, 48) : s;
  }

  String get effectiveQrPayload {
    if (qrPayload != null && qrPayload!.trim().isNotEmpty) {
      return qrPayload!.trim();
    }
    return sku.trim().isEmpty ? effectiveBarcodeAscii : sku.trim();
  }
}
