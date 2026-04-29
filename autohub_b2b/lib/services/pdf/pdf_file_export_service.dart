import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Сохранение PDF через нативный диалог «Сохранить как».
///
/// Десктоп: [getSaveLocation] (Windows/macOS/Linux).
/// Мобильные ОС: [FilePicker.platform.saveFile], где доступно.
///
/// Сборка macOS для Mac App Store: путь из диалога пользователя обычно покрывается
/// entitlement «user-selected file»; при произвольном доступе к каталогам нужны
/// отдельные entitlements (см. документацию Apple).
class PdfFileExportService {
  PdfFileExportService._();

  static const _pdfGroup = XTypeGroup(
    label: 'PDF',
    extensions: ['pdf'],
  );

  static String _withPdfExtension(String name) {
    final t = name.trim();
    if (t.isEmpty) return 'document.pdf';
    return t.toLowerCase().endsWith('.pdf') ? t : '$t.pdf';
  }

  /// Возвращает путь к сохранённому файлу или `null` при отмене / ошибке.
  static Future<String?> savePdf({
    required List<int> bytes,
    required String suggestedName,
  }) async {
    if (kIsWeb) {
      return null;
    }
    final name = _withPdfExtension(suggestedName);

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: const [_pdfGroup],
      );
      if (location == null) return null;
      final file = File(location.path);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final path = await FilePicker.platform.saveFile(
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null) return null;
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    }

    return null;
  }
}
