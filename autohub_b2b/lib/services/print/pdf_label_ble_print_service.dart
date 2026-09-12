import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:autohub_b2b/models/label_size_preset.dart';
import 'package:autohub_b2b/services/pdf/label_pdf_service.dart';

/// Растрирует уже сгенерированный этикеточный PDF и собирает поток ESC/POS с картинками GS (v0) через [Generator].
class PdfLabelBlePrintService {
  PdfLabelBlePrintService._();

  /// [esc_pos_utils_plus] при `widthPx % 8 != 0` строит буфер через [List.filled] и падает на
  /// `insertAll` с «cannot add to a fixed-length list» (типичный растр 60×40 мм × 203 DPI).
  static Image _ensureWidthMultipleOf8ForEscPos(Image image) {
    final w = image.width;
    if (w <= 0 || w % 8 == 0) return image;
    final targetW = (w + 7) ~/ 8 * 8;
    return copyExpandCanvas(
      image,
      newWidth: targetW,
      newHeight: image.height,
      position: ExpandCanvasPosition.topCenter,
      backgroundColor: ColorRgb8(255, 255, 255),
    );
  }

  /// Ширина головки по фактической ширине первой строки страницы PDF (с учётом «поперёк»).
  static PaperSize paperSizeForPageFormat(PdfPageFormat f) {
    final wMm = f.width / PdfPageFormat.mm;
    return wMm <= 54 ? PaperSize.mm58 : PaperSize.mm80;
  }

  /// Fallback по пресету (до генерации страницы).
  static PaperSize paperSizeForPreset(LabelSizePreset preset) =>
      paperSizeForPageFormat(preset.toPdfPageFormat());

  /// DPI растра: ниже для длинных этикеток, чтобы объём данных по BLE оставался разумным.
  static double rasterDpiFor(LabelPdfResult result) {
    final hMm = result.pageFormat.height / PdfPageFormat.mm;
    if (hMm >= 120) return 120;
    if (hMm >= 55) return 160;
    return 203;
  }

  /// Сырые ESC/POS байты: каждая страница PDF — отдельное изображение, в конце отрез.
  static Future<List<int>> buildEscPosBytes(LabelPdfResult result, {required PaperSize paperSize}) async {
    final info = await Printing.info();
    if (!info.canRaster) {
      throw UnsupportedError(
        'На этом устройстве недоступно растрирование PDF для BLE. Обновите приложение или проверьте платформу.',
      );
    }

    final dpi = rasterDpiFor(result);
    final profile = await CapabilityProfile.load();
    final g = Generator(paperSize, profile);
    final out = <int>[...g.reset()];

    var pages = 0;
    await for (final raster in Printing.raster(
      result.bytes,
      dpi: dpi,
    )) {
      pages++;
      final image =
          _ensureWidthMultipleOf8ForEscPos(raster.asImage());
      out.addAll(
        g.imageRaster(
          image,
          align: PosAlign.center,
          highDensityHorizontal: true,
          highDensityVertical: true,
          imageFn: PosImageFn.graphics,
        ),
      );
      out.addAll(g.feed(2));
    }

    if (pages == 0) {
      throw StateError('PDF не содержит страниц для печати.');
    }

    out.addAll(g.cut());
    return out;
  }
}
