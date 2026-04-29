import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

/// ESC/POS over raw TCP using [NetworkPrinter]
/// (package `esc_pos_printer_plus` — same [NetworkPrinter] API as legacy `esc_pos_printer`,
/// bound to `esc_pos_utils_plus` / `image` ^4 for dependency resolution with current app stack).
class EscPosNetworkReceiptService {
  EscPosNetworkReceiptService._();

  /// Short test ticket — Latin text for widest ESC/POS firmware compatibility.
  static Future<PosPrintResult> printTestReceipt(
    String host, {
    int port = 9100,
    Duration connectTimeout = const Duration(seconds: 5),
    PaperSize paper = PaperSize.mm80,
  }) async {
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    // Always pass port explicitly (some package versions default to a wrong value).
    final connect = await printer.connect(
      host,
      port: port,
      timeout: connectTimeout,
    );
    if (connect != PosPrintResult.success) {
      return connect;
    }

    try {
      final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      printer.setStyles(PosStyles(align: PosAlign.center));
      printer.text(
        'Auto+ Pro',
        styles: const PosStyles(align: PosAlign.center, bold: true),
        linesAfter: 1,
      );
      printer.hr();
      printer.setStyles(const PosStyles(align: PosAlign.left));
      printer.text('ESC/POS network test');
      printer.text('IP: $host:$port');
      printer.text(ts);
      printer.emptyLines(1);
      printer.text(
        'If this printed, Wi-Fi ESC/POS works.',
        styles: const PosStyles(align: PosAlign.left),
      );
      printer.feed(2);
      printer.cut();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    } finally {
      printer.disconnect(delayMs: 40);
    }

    return PosPrintResult.success;
  }
}
