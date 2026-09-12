import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';

/// Печать этикетки через TSPL (Thermal Shipping Printer Language) по BLE.
///
/// Протокол TSPL — текстовые ASCII-команды, передаваемые как UTF-8 байты прямо
/// в UART-мост принтера (UUID `49535343-6daa` на AiYin IP-802BT).
/// Никакого растрирования PDF не требуется: команды компактны (~300–600 байт).
///
/// Документация TSPL: https://www.tscprinters.com/en/support/download/download_detail/TSPL_TSPL2.pdf
class TsplBleLabelService {
  TsplBleLabelService._();

  /// Точек на мм при 203 DPI (стандарт для AiYin IP-802BT).
  static const double _dotPerMm = 203 / 25.4; // ≈ 8 dot/mm

  static int _mm(double mm) => (mm * _dotPerMm).round();

  /// Задержка между чанками UART на iOS — чуть больше чем для ESC/POS,
  /// поскольку TSPL-команды разбиваются по границам байтов, не по строкам.
  static const Duration _iosInterChunkDelay = Duration(milliseconds: 50);

  // ---------------------------------------------------------------------------
  // Построение TSPL
  // ---------------------------------------------------------------------------

  /// Собирает полный TSPL-сценарий для этикетки [product].
  ///
  /// [widthMm]   — ширина ленты в мм (по умолчанию 84, тип AiYin IP-802BT).
  /// [heightMm]  — длина этикетки в мм (по умолчанию 90).
  /// [copies]    — количество копий.
  static String buildTspl(
    LabelProductData product, {
    double widthMm = 84,
    double heightMm = 90,
    int copies = 1,
  }) {
    final buf = StringBuffer();

    // Размер этикетки и зазор между ними.
    buf.writeln('SIZE ${widthMm.toStringAsFixed(0)} mm, ${heightMm.toStringAsFixed(0)} mm');
    buf.writeln('GAP 3 mm, 0 mm');

    // DIRECTION 1 — текст параллельно длинному краю (поперёк ленты).
    buf.writeln('DIRECTION 1');

    // Очистить буфер перед новой этикеткой.
    buf.writeln('CLS');

    // UTF-8 для кириллицы (поддерживается прошивками AiYin v2+).
    buf.writeln('CODEPAGE UTF-8');

    // Доступная область в точках.
    final int W = _mm(widthMm); // ~672 dot
    final int H = _mm(heightMm); // ~720 dot
    final int xLeft = 16;
    // Правая граница (для будущей выравнивания справа).
    // ignore: unused_local_variable
    final int xRight = W - 16;
    int y = 16;

    // --- Заголовок «Auto+ Pro» ---
    buf.writeln('TEXT $xLeft,$y,"4",0,1,1,"Auto+ Pro"');
    y += 42;

    // Горизонтальная линия.
    buf.writeln('BAR $xLeft,$y,${W - xLeft * 2},2');
    y += 10;

    // --- Название товара (до 2 строк по 28 символов шрифт "3") ---
    final name = _safe(product.productName);
    final line1 = name.length > 28 ? name.substring(0, 28) : name;
    final line2 =
        name.length > 28 ? name.substring(28, math.min(56, name.length)) : null;

    buf.writeln('TEXT $xLeft,$y,"3",0,1,1,"$line1"');
    y += 44;
    if (line2 != null && line2.trim().isNotEmpty) {
      buf.writeln('TEXT $xLeft,$y,"3",0,1,1,"$line2"');
      y += 44;
    }

    // --- Артикул ---
    if (product.sku.isNotEmpty) {
      buf.writeln('TEXT $xLeft,$y,"2",0,1,1,"Арт: ${_safe(product.sku)}"');
      y += 32;
    }

    // --- Ячейка склада ---
    if (product.showWarehouseCell &&
        product.warehouseCell != null &&
        product.warehouseCell!.trim().isNotEmpty) {
      buf.writeln(
        'TEXT $xLeft,$y,"2",0,1,1,"Ячейка: ${_safe(product.warehouseCell!)}"',
      );
      y += 32;
    }

    // --- Цена (крупный шрифт) ---
    if (product.showPrice && product.price != null) {
      final price =
          '${product.price!.toStringAsFixed(0)} ${product.currencySymbol}';
      buf.writeln('TEXT $xLeft,$y,"4",0,1,1,"$price"');
      y += 56;
    }

    y += 8; // отступ перед штрихкодом

    // --- CODE128 (только ASCII из effectiveBarcodeAscii) ---
    if (product.showBarcode && product.effectiveBarcodeAscii.isNotEmpty) {
      // BARCODE x,y,"type",height,readable,rotation,narrow,wide,"data"
      buf.writeln(
        'BARCODE $xLeft,$y,"128",60,1,0,2,3,"${product.effectiveBarcodeAscii}"',
      );
      y += 90;
    }

    // --- QR-код (располагаем, если есть место до конца холста) ---
    if (product.showQr && y + 80 < H) {
      final qr = _safe(product.effectiveQrPayload);
      // QRCODE x,y,ECC level,cell width,mode,rotation,"data"
      buf.writeln('QRCODE $xLeft,$y,M,4,A,0,"$qr"');
    }

    // --- Печать ---
    buf.writeln('PRINT ${math.max(1, copies)},1');

    debugPrint('[TSPL] ${buf.length} chars → ${utf8.encode(buf.toString()).length} bytes');
    return buf.toString();
  }

  /// Минимальный тест: пустая этикетка с одной строкой — проверяем, что UART
  /// действительно принимает TSPL.
  static String buildTestTspl({double widthMm = 84, double heightMm = 90}) {
    final buf = StringBuffer();
    buf.writeln('SIZE ${widthMm.toStringAsFixed(0)} mm, ${heightMm.toStringAsFixed(0)} mm');
    buf.writeln('GAP 3 mm, 0 mm');
    buf.writeln('DIRECTION 1');
    buf.writeln('CLS');
    buf.writeln('CODEPAGE UTF-8');
    buf.writeln('TEXT 16,20,"4",0,1,1,"TSPL TEST"');
    buf.writeln('TEXT 16,70,"2",0,1,1,"Auto+ BLE OK"');
    buf.writeln('PRINT 1,1');
    return buf.toString();
  }

  // ---------------------------------------------------------------------------
  // Отправка по BLE
  // ---------------------------------------------------------------------------

  /// Отправляет TSPL-команды на подключённый BLE-принтер.
  ///
  /// TSPL — чистый ASCII-текст; никакого растрирования не нужно.
  /// Чанки по 20 байт с задержкой 50 мс — стабильно для ISSC UART на iOS.
  ///
  /// [transposePhysical] — поменять ширину и высоту местами (ротация 90°).
  static Future<void> printViaBle(
    LabelProductData product, {
    double widthMm = 84,
    double heightMm = 90,
    int copies = 1,
    bool transposePhysical = false,
  }) async {
    final w = transposePhysical ? heightMm : widthMm;
    final h = transposePhysical ? widthMm : heightMm;
    final tspl = buildTspl(product, widthMm: w, heightMm: h, copies: copies);
    await _sendTspl(tspl);
  }

  /// Минимальный тест печати TSPL через BLE.
  static Future<void> printTestViaBle({
    double widthMm = 84,
    double heightMm = 90,
  }) async {
    final tspl = buildTestTspl(widthMm: widthMm, heightMm: heightMm);
    await _sendTspl(tspl);
  }

  static Future<void> _sendTspl(String tspl) async {
    final session = BleThermalPrintCoordinator.session;
    if (!session.isReady) {
      throw BleEscPosException(
        'Принтер не подключён. Подключитесь через «Настройки принтера → Bluetooth LE».',
      );
    }

    final bytes = utf8.encode(tspl);
    debugPrint('[TSPL] Sending ${bytes.length} bytes:\n$tspl');

    // Чанки 20 байт, 50 мс пауза — рекомендовано для AiYin IP-802BT UART.
    await session.writeEscPosBytes(
      bytes,
      interChunkDelay: _iosInterChunkDelay,
      writeTimeoutSec: 8,
    );
  }

  // ---------------------------------------------------------------------------
  // Вспомогательные
  // ---------------------------------------------------------------------------

  /// Убирает символы, опасные для TSPL-строк в кавычках.
  static String _safe(String s) =>
      s.replaceAll('"', "'").replaceAll('\r', '').replaceAll('\n', ' ').trim();
}
