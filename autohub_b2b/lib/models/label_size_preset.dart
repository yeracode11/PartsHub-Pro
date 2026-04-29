import 'package:pdf/pdf.dart';

/// Предустановленные размеры этикетки в мм (фиксированный MediaBox PDF, не A4).
enum LabelSizePreset {
  /// Узкая полка
  mm50x30(50, 30),

  /// Универсальная мини-этикетка
  mm60x40(60, 40),

  /// Крупная / палета
  mm100x150(100, 150);

  const LabelSizePreset(this.widthMm, this.heightMm);

  final double widthMm;
  final double heightMm;

  /// Поля в мм (малые, чтобы максимум полезной площади).
  double get marginMm {
    switch (this) {
      case LabelSizePreset.mm50x30:
        return 1.0;
      case LabelSizePreset.mm60x40:
        return 1.2;
      case LabelSizePreset.mm100x150:
        return 2.0;
    }
  }

  /// Формат страницы PDF в пунктах (как в пакете `pdf`).
  PdfPageFormat toPdfPageFormat() {
    final m = marginMm * PdfPageFormat.mm;
    return PdfPageFormat(
      widthMm * PdfPageFormat.mm,
      heightMm * PdfPageFormat.mm,
      marginLeft: m,
      marginTop: m,
      marginRight: m,
      marginBottom: m,
    );
  }
}
