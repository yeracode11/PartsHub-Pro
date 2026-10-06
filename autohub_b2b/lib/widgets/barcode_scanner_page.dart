import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Камера на весь экран: возвращает первый распознанный код или null.
class BarcodeScannerPage extends StatefulWidget {
  final String title;

  const BarcodeScannerPage({super.key, this.title = 'Сканировать штрихкод'});

  static Future<String?> scan(BuildContext context, {String? title}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => title == null
            ? const BarcodeScannerPage()
            : BarcodeScannerPage(title: title),
      ),
    );
  }

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes
        .map((b) => b.rawValue?.trim())
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code == null) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error, child) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Камера недоступна. Закройте экран и введите код вручную.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
