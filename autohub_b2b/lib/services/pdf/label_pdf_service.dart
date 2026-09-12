import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:autohub_b2b/models/generated_pdf_document.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/models/label_size_preset.dart';

/// Результат генерации: байты PDF и тот же [PdfPageFormat], что нужен для печати без масштабирования.
class LabelPdfResult implements GeneratedPdfDocument {
  const LabelPdfResult({
    required this.bytes,
    required this.pageFormat,
  });

  @override
  final Uint8List bytes;
  @override
  final PdfPageFormat pageFormat;
}

/// Генерация **фиксированного** размера этикетки (не A4): MediaBox = ширина×высота в мм.
class LabelPdfService {
  LabelPdfService();

  static final _money = NumberFormat('#,##0.##', 'ru_RU');

  /// Печать «поперёк»: меняет местами ширину и высоту страницы (Margins без изменений).
  static PdfPageFormat transposePhysicalPage(PdfPageFormat base) {
    return PdfPageFormat(
      base.height,
      base.width,
      marginTop: base.marginTop,
      marginBottom: base.marginBottom,
      marginLeft: base.marginLeft,
      marginRight: base.marginRight,
    );
  }

  /// PDF этикетки фиксированного размера. [copies] — число одинаковых страниц (для пачки этикеток).
  Future<LabelPdfResult> generateLabel(
    LabelProductData product,
    LabelSizePreset size, {
    int copies = 1,
    bool transposePhysical = false,
  }) async {
    final n = copies.clamp(1, 99);
    final baseFmt = size.toPdfPageFormat();
    final pageFormat =
        transposePhysical ? transposePhysicalPage(baseFmt) : baseFmt;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    pw.ImageProvider? logo;
    final logoPath = product.logoAssetPath.trim();
    if (logoPath.isNotEmpty) {
      try {
        final data = await rootBundle.load(logoPath);
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    for (var i = 0; i < n; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (ctx) => _buildLabel(
            ctx,
            product: product,
            size: size,
            logo: logo,
            layoutPageFormat: pageFormat,
          ),
        ),
      );
    }

    final bytes = await doc.save();
    return LabelPdfResult(bytes: bytes, pageFormat: pageFormat);
  }

  /// Один PDF: по одной странице-этикетке на каждый товар (массовая печать со списка).
  Future<LabelPdfResult> generateLabelsForItems(
    List<LabelProductData> products,
    LabelSizePreset size,
  ) async {
    if (products.isEmpty) {
      throw ArgumentError('Список товаров пуст');
    }
    final pageFormat = size.toPdfPageFormat();
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    pw.ImageProvider? logo;
    final logoPath = products.first.logoAssetPath.trim();
    if (logoPath.isNotEmpty) {
      try {
        final data = await rootBundle.load(logoPath);
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }
    }

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    for (final product in products) {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (ctx) => _buildLabel(
            ctx,
            product: product,
            size: size,
            logo: logo,
            layoutPageFormat: pageFormat,
          ),
        ),
      );
    }

    final bytes = await doc.save();
    return LabelPdfResult(bytes: bytes, pageFormat: pageFormat);
  }

  pw.Widget _buildLabel(
    pw.Context context, {
    required LabelProductData product,
    required LabelSizePreset size,
    required pw.ImageProvider? logo,
    required PdfPageFormat layoutPageFormat,
  }) {
    final aw = layoutPageFormat.availableWidth;
    final ah = layoutPageFormat.availableHeight;

    final nameSize = _nameFontPt(size);
    final metaSize = (nameSize - 1).clamp(5.0, 9.0);
    final priceSize = (nameSize - 0.5).clamp(6.0, 12.0);

    final showQr = product.showQr && size != LabelSizePreset.mm50x30;
    final barcodeHeight = (ah * (size == LabelSizePreset.mm100x150 ? 0.22 : 0.38))
        .clamp(16.0, aw * 0.45);

    final children = <pw.Widget>[];

    if (size == LabelSizePreset.mm100x150 && logo != null) {
      children.add(
        pw.Center(
          child: pw.Image(logo, width: aw * 0.35),
        ),
      );
      children.add(pw.SizedBox(height: ah * 0.02));
      children.add(
        pw.Text(
          product.productName,
          style: pw.TextStyle(
            fontSize: nameSize,
            fontWeight: pw.FontWeight.bold,
          ),
          maxLines: 5,
          overflow: pw.TextOverflow.clip,
        ),
      );
    } else if (logo != null && size == LabelSizePreset.mm60x40) {
      children.add(
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: aw * 0.22),
            pw.SizedBox(width: aw * 0.02),
            pw.Expanded(
              child: pw.Text(
                product.productName,
                style: pw.TextStyle(
                  fontSize: nameSize,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 3,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ],
        ),
      );
    } else {
      children.add(
        pw.Text(
          product.productName,
          style: pw.TextStyle(
            fontSize: nameSize,
            fontWeight: pw.FontWeight.bold,
          ),
          maxLines: size == LabelSizePreset.mm50x30
              ? 2
              : (size == LabelSizePreset.mm100x150 ? 5 : 3),
          overflow: pw.TextOverflow.clip,
        ),
      );
    }

    children.add(pw.SizedBox(height: ah * 0.02));
    children.add(
      pw.Text(
        'Арт: ${product.sku}',
        style: pw.TextStyle(fontSize: metaSize, color: PdfColors.grey800),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );

    if (product.showWarehouseCell &&
        product.warehouseCell != null &&
        product.warehouseCell!.trim().isNotEmpty) {
      children.add(pw.SizedBox(height: ah * 0.012));
      children.add(
        pw.Text(
          'Яч.: ${product.warehouseCell!.trim()}',
          style: pw.TextStyle(fontSize: metaSize * 0.95, color: PdfColors.grey900),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
        ),
      );
    }

    if (product.showPrice && product.price != null) {
      children.add(pw.SizedBox(height: ah * 0.015));
      children.add(
        pw.Text(
          '${_money.format(product.price)} ${product.currencySymbol}',
          style: pw.TextStyle(
            fontSize: priceSize,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
      );
    }

    /// Нижний блок (штрихкод / QR) всегда получает место: иначе при переполнении
    /// верхним текстом [pw.Column] в пакете `pdf` обрывает вёрстку и коды не рисуются.
    pw.Widget? bottomBlock;
    if (product.showBarcode) {
      if (showQr) {
        final qrSide = (aw * 0.28).clamp(18.0, barcodeHeight * 1.1);
        bottomBlock = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.BarcodeWidget(
                barcode: Barcode.code128(),
                data: product.effectiveBarcodeAscii,
                drawText: true,
                height: barcodeHeight,
                textStyle: pw.TextStyle(fontSize: metaSize * 0.85),
              ),
            ),
            pw.SizedBox(width: aw * 0.02),
            pw.BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: product.effectiveQrPayload,
              drawText: false,
              width: qrSide,
              height: qrSide,
            ),
          ],
        );
      } else {
        bottomBlock = pw.BarcodeWidget(
          barcode: Barcode.code128(),
          data: product.effectiveBarcodeAscii,
          drawText: true,
          height: barcodeHeight,
          textStyle: pw.TextStyle(fontSize: metaSize * 0.85),
        );
      }
    } else if (product.showQr) {
      final qrSide = (aw * 0.42).clamp(24.0, ah * 0.5);
      bottomBlock = pw.Center(
        child: pw.BarcodeWidget(
          barcode: Barcode.qrCode(),
          data: product.effectiveQrPayload,
          drawText: false,
          width: qrSide,
          height: qrSide,
        ),
      );
    }

    final gapBeforeCodes = bottomBlock != null ? ah * 0.02 : 0.0;

    return pw.SizedBox(
      width: aw,
      height: ah,
      child: bottomBlock == null
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: children,
            )
          : pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.ClipRect(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
                if (gapBeforeCodes > 0) pw.SizedBox(height: gapBeforeCodes),
                bottomBlock,
              ],
            ),
    );
  }

  double _nameFontPt(LabelSizePreset size) {
    switch (size) {
      case LabelSizePreset.mm50x30:
        return 6.5;
      case LabelSizePreset.mm60x40:
        return 7.5;
      case LabelSizePreset.mm100x150:
        return 11;
    }
  }
}
