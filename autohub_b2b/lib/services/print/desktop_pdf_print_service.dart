import 'package:autohub_b2b/models/generated_pdf_document.dart';
import 'package:autohub_b2b/services/pdf/system_pdf_print_service.dart';

/// Точка входа для сценариев «офис / склад» на десктопе: тот же движок, что и на мобильных.
class DesktopPdfPrintService {
  DesktopPdfPrintService._();

  static Future<bool> printPdf(
    GeneratedPdfDocument document, {
    String jobName = 'document.pdf',
  }) {
    return SystemPdfPrintService.printGenerated(document, jobName: jobName);
  }
}
