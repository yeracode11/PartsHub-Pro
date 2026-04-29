import 'dart:typed_data';

import 'package:pdf/pdf.dart';

import 'package:autohub_b2b/services/pdf/label_pdf_service.dart';
import 'package:autohub_b2b/services/pdf/system_pdf_print_service.dart';

/// Печать этикетки через системный диалог (`printing`).
///
/// Важно передавать тот же [PdfPageFormat], что при генерации — иначе ОС может
/// подставить A4 и масштабировать. На iOS/macOS включается [forceCustomPrintPaper].
class LabelPrintService {
  LabelPrintService._();

  /// Печать готового PDF (одна страница, фиксированный MediaBox).
  static Future<bool> printLabel({
    required Uint8List pdfBytes,
    required PdfPageFormat pageFormat,
    String jobName = 'label.pdf',
  }) {
    return SystemPdfPrintService.printDocument(
      pdfBytes: pdfBytes,
      pageFormat: pageFormat,
      jobName: jobName,
    );
  }

  /// Удобная обёртка после [LabelPdfService.generateLabel].
  static Future<bool> printLabelResult(
    LabelPdfResult result, {
    String jobName = 'label.pdf',
  }) {
    return SystemPdfPrintService.printGenerated(result, jobName: jobName);
  }
}
