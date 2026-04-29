import 'dart:typed_data';

import 'package:pdf/pdf.dart';

/// Общий контракт для PDF, сгенерированного под фиксированный [PdfPageFormat]
/// (чек 80 мм, этикетка, A4 и т.д.) — нужен для печати без подмены формата ОС.
abstract class GeneratedPdfDocument {
  Uint8List get bytes;
  PdfPageFormat get pageFormat;
}
