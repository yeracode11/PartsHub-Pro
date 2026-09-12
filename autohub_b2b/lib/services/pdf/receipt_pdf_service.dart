import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:autohub_b2b/models/generated_pdf_document.dart';
import 'package:autohub_b2b/models/receipt_document_model.dart';

/// Макет чека: узкая лента 80 мм (термо) или полноценная A4 — только по выбору пользователя.
enum ReceiptLayout {
  /// Термочек 80 мм (высота страницы для MultiPage — стандартная «листовая» длина).
  thermal80mm,

  /// Полноформатный документ на A4.
  a4,
}

/// Результат генерации PDF счёта с корректным [pageFormat] для печати и предпросмотра.
class ReceiptPdfResult implements GeneratedPdfDocument {
  const ReceiptPdfResult({
    required this.bytes,
    required this.pageFormat,
  });

  @override
  final Uint8List bytes;
  @override
  final PdfPageFormat pageFormat;
}

/// Генерация PDF счёта/чека (пакет `pdf`).
class ReceiptPdfService {
  ReceiptPdfService();

  static final NumberFormat _moneyRu =
      NumberFormat.currency(locale: 'ru_RU', symbol: '', decimalDigits: 2);

  /// Ширина термоленты 80 мм; высота страницы — для переносов MultiPage (не подмена на A4 в UI).
  static PdfPageFormat thermal80PageFormat() {
    const margin = 4 * PdfPageFormat.mm;
    return PdfPageFormat(
      80 * PdfPageFormat.mm,
      297 * PdfPageFormat.mm,
      marginLeft: margin,
      marginRight: margin,
      marginTop: margin,
      marginBottom: margin,
    );
  }

  Future<ReceiptPdfResult> generate(
    ReceiptDocumentData data, {
    ReceiptLayout layout = ReceiptLayout.thermal80mm,
  }) async {
    try {
      final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );

      pw.ImageProvider? logo;
      try {
        final logoBytes = await rootBundle.load(data.logoAssetPath);
        logo = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );

      final pageFormat = layout == ReceiptLayout.thermal80mm
          ? thermal80PageFormat()
          : PdfPageFormat.a4;

      final margin = layout == ReceiptLayout.thermal80mm
          ? pw.EdgeInsets.zero
          : const pw.EdgeInsets.all(40);

      doc.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: margin,
          build: (context) => layout == ReceiptLayout.thermal80mm
              ? _buildThermal80(
                  data,
                  logo: logo,
                  regular: regular,
                  bold: bold,
                )
              : _buildA4(
                  data,
                  logo: logo,
                  regular: regular,
                  bold: bold,
                ),
        ),
      );

      final bytes = await doc.save();
      return ReceiptPdfResult(bytes: bytes, pageFormat: pageFormat);
    } catch (e, st) {
      Error.throwWithStackTrace(
        Exception('Не удалось сформировать PDF. Попробуйте ещё раз.'),
        st,
      );
    }
  }

  List<pw.Widget> _buildThermal80(
    ReceiptDocumentData data, {
    required pw.ImageProvider? logo,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final dateStr =
        DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(data.issuedAt.toLocal());

    return [
      if (logo != null)
        pw.Center(
          child: pw.Image(logo, width: 48 * PdfPageFormat.mm),
        ),
      if (logo != null) pw.SizedBox(height: 6),
      pw.Center(
        child: pw.Text(
          data.companyName,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: bold),
          textAlign: pw.TextAlign.center,
        ),
      ),
      if (data.companySubtitle != null) ...[
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            data.companySubtitle!,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, font: regular),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
      pw.SizedBox(height: 8),
      pw.Text(
        'Заказ ${data.orderNumber}',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: bold),
      ),
      pw.Text('Дата: $dateStr', style: pw.TextStyle(fontSize: 7, font: regular)),
      if (data.customerName != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'Покупатель: ${data.customerName}',
            style: pw.TextStyle(fontSize: 7, font: regular),
          ),
        ),
      if (data.paymentInfo != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            data.paymentInfo!,
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey800, font: regular),
          ),
        ),
      pw.SizedBox(height: 8),
      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
      pw.SizedBox(height: 4),
      _thermalTable(data, regular: regular, bold: bold),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Итого',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, font: bold),
            ),
            pw.Text(
              _formatMoney(data.total, data.currencySymbol),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: bold),
            ),
          ],
        ),
      ),
      if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 10),
        pw.Text(
          'Примечания',
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, font: bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(data.notes!, style: pw.TextStyle(fontSize: 6, font: regular)),
      ],
    ];
  }

  pw.Widget _thermalTable(
    ReceiptDocumentData data, {
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final headerStyle = pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, font: bold);
    final cellStyle = pw.TextStyle(fontSize: 6, font: regular);

    return pw.Table(
      border: pw.TableBorder.symmetric(inside: const pw.BorderSide(width: 0.2)),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.2),
        1: const pw.FlexColumnWidth(0.7),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.1),
      },
      children: [
        pw.TableRow(
          children: [
            _cell('Товар', headerStyle, pw.Alignment.centerLeft),
            _cell('Кол.', headerStyle, pw.Alignment.centerRight),
            _cell('Цена', headerStyle, pw.Alignment.centerRight),
            _cell('Сумма', headerStyle, pw.Alignment.centerRight),
          ],
        ),
        ...data.lines.map(
          (e) => pw.TableRow(
            children: [
              _cell(e.name, cellStyle, pw.Alignment.centerLeft),
              _cell('${e.quantity}', cellStyle, pw.Alignment.centerRight),
              _cell(_formatMoney(e.unitPrice, data.currencySymbol), cellStyle, pw.Alignment.centerRight),
              _cell(_formatMoney(e.lineTotal, data.currencySymbol), cellStyle, pw.Alignment.centerRight),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _cell(String text, pw.TextStyle style, pw.Alignment align) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: pw.Align(
        alignment: align,
        child: pw.Text(text, style: style),
      ),
    );
  }

  List<pw.Widget> _buildA4(
    ReceiptDocumentData data, {
    required pw.ImageProvider? logo,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final dateStr =
        DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(data.issuedAt.toLocal());

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Image(logo, width: 120),
                ),
              pw.Text(
                data.companyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: bold,
                ),
              ),
              if (data.companySubtitle != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    data.companySubtitle!,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      font: regular,
                    ),
                  ),
                ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Счёт / заказ',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey800,
                  font: regular,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.orderNumber,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  font: bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text('Дата: $dateStr', style: pw.TextStyle(fontSize: 10, font: regular)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 20),
      if (data.customerName != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            'Покупатель: ${data.customerName}',
            style: pw.TextStyle(fontSize: 11, font: regular),
          ),
        ),
      if (data.paymentInfo != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            data.paymentInfo!,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800, font: regular),
          ),
        ),
      pw.TableHelper.fromTextArray(
        headers: ['Товар', 'Кол-во', 'Цена', 'Сумма'],
        data: data.lines
            .map(
              (e) => [
                e.name,
                '${e.quantity}',
                _formatMoney(e.unitPrice, data.currencySymbol),
                _formatMoney(e.lineTotal, data.currencySymbol),
              ],
            )
            .toList(),
        headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          font: bold,
        ),
        cellStyle: pw.TextStyle(fontSize: 10, font: regular),
        headerAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
      ),
      pw.SizedBox(height: 16),
      pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'Итого: ',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  font: bold,
                ),
              ),
              pw.Text(
                _formatMoney(data.total, data.currencySymbol),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  font: bold,
                ),
              ),
            ],
          ),
        ),
      ),
      if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
        pw.SizedBox(height: 24),
        pw.Text(
          'Примечания',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
            font: bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(data.notes!, style: pw.TextStyle(fontSize: 9, font: regular)),
      ],
    ];
  }

  String _formatMoney(double value, String symbol) {
    final s = _moneyRu.format(value).trim();
    return '$s $symbol';
  }
}
