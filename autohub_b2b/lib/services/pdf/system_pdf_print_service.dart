import 'dart:typed_data';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:autohub_b2b/models/generated_pdf_document.dart';

/// Системная печать PDF с явным [PdfPageFormat] (без динамической подстановки A4).
///
/// На iOS/macOS включается [forceCustomPrintPaper] для фиксированных размеров.
class SystemPdfPrintService {
  SystemPdfPrintService._();

  static bool get _forceCustomPrintPaper {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Печать готового PDF (MediaBox уже задан при генерации).
  static Future<bool> printDocument({
    required Uint8List pdfBytes,
    required PdfPageFormat pageFormat,
    String jobName = 'document.pdf',
  }) {
    return Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdfBytes,
      name: jobName,
      format: pageFormat,
      dynamicLayout: false,
      forceCustomPrintPaper: _forceCustomPrintPaper,
    );
  }

  static Future<bool> printGenerated(GeneratedPdfDocument doc, {String? jobName}) {
    return printDocument(
      pdfBytes: doc.bytes,
      pageFormat: doc.pageFormat,
      jobName: jobName ?? 'document.pdf',
    );
  }
}
