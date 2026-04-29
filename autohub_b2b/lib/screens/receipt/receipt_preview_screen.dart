import 'package:flutter/material.dart';

import 'package:autohub_b2b/models/receipt_document_model.dart';
import 'package:autohub_b2b/screens/pdf/pdf_preview_screen.dart';
import 'package:autohub_b2b/services/pdf/receipt_pdf_service.dart';

/// Предпросмотр PDF счёта: печать с корректным форматом (80 мм или A4), сохранение, шаринг на мобильных.
class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.document,
  });

  final ReceiptDocumentData document;

  static Future<void> open(BuildContext context, ReceiptDocumentData document) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ReceiptPreviewScreen(document: document),
      ),
    );
  }

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final _pdf = ReceiptPdfService();
  ReceiptLayout _layout = ReceiptLayout.thermal80mm;

  String get _safeFileName {
    final raw = widget.document.orderNumber.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return 'receipt_$raw.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return PdfPreviewScreen(
      key: ValueKey(_layout),
      title: 'Заказ ${widget.document.orderNumber}',
      generate: () => _pdf.generate(widget.document, layout: _layout),
      suggestedFileName: _safeFileName,
      shareSubject: 'Заказ ${widget.document.orderNumber}',
      appBarActions: [
        PopupMenuButton<ReceiptLayout>(
          tooltip: 'Формат страницы',
          onSelected: (v) => setState(() => _layout = v),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: ReceiptLayout.thermal80mm,
              child: Row(
                children: [
                  Expanded(child: Text('Чек 80 мм')),
                  if (_layout == ReceiptLayout.thermal80mm)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
            PopupMenuItem(
              value: ReceiptLayout.a4,
              child: Row(
                children: [
                  const Expanded(child: Text('A4')),
                  if (_layout == ReceiptLayout.a4)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
