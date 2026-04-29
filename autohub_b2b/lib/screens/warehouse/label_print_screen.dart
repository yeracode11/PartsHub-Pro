import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/models/label_size_preset.dart';
import 'package:autohub_b2b/services/pdf/label_pdf_service.dart';
import 'package:autohub_b2b/services/pdf/pdf_file_export_service.dart';
import 'package:autohub_b2b/services/print/label_print_service.dart';

/// Печать этикетки фиксированного размера (PDF) из данных [LabelProductData] (обычно из карточки товара).
class LabelPrintScreen extends StatefulWidget {
  const LabelPrintScreen({
    super.key,
    required this.product,
  });

  final LabelProductData product;

  @override
  State<LabelPrintScreen> createState() => _LabelPrintScreenState();
}

class _LabelPrintScreenState extends State<LabelPrintScreen> {
  final _pdf = LabelPdfService();
  final _copiesCtrl = TextEditingController(text: '1');

  LabelSizePreset _size = LabelSizePreset.mm60x40;
  bool _showPrice = true;
  bool _showBarcode = true;
  bool _showQr = true;
  bool _showCell = true;

  late Future<LabelPdfResult> _resultFuture;

  @override
  void initState() {
    super.initState();
    _showPrice = widget.product.showPrice;
    _showBarcode = widget.product.showBarcode;
    _showQr = widget.product.showQr;
    _showCell = widget.product.showWarehouseCell;
    _resultFuture = _generate();
  }

  @override
  void dispose() {
    _copiesCtrl.dispose();
    super.dispose();
  }

  LabelProductData _effectiveProduct() {
    return LabelProductData(
      productName: widget.product.productName,
      sku: widget.product.sku,
      price: widget.product.price,
      currencySymbol: widget.product.currencySymbol,
      showPrice: _showPrice,
      showBarcode: _showBarcode,
      showQr: _showQr,
      showWarehouseCell: _showCell,
      qrPayload: widget.product.qrPayload,
      barcodeData: widget.product.barcodeData,
      logoAssetPath: widget.product.logoAssetPath,
      warehouseCell: widget.product.warehouseCell,
    );
  }

  int _parseCopies() {
    final v = int.tryParse(_copiesCtrl.text.trim()) ?? 1;
    return v.clamp(1, 99);
  }

  Future<LabelPdfResult> _generate() {
    return _pdf.generateLabel(
      _effectiveProduct(),
      _size,
      copies: _parseCopies(),
    );
  }

  void _scheduleGenerate() {
    setState(() {
      _resultFuture = _generate();
    });
  }

  String get _suggestedPdfName {
    final raw = widget.product.sku.replaceAll(RegExp(r'[^\w\-]+'), '_');
    return 'label_${raw}_${_size.widthMm}x${_size.heightMm}.pdf';
  }

  Future<void> _print() async {
    try {
      final result = await _resultFuture;
      final ok = await LabelPrintService.printLabelResult(
        result,
        jobName: _suggestedPdfName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Отправлено на печать' : 'Печать отменена'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (kIsWeb) return;
    try {
      final result = await _resultFuture;
      if (!mounted) return;
      final path = await PdfFileExportService.savePdf(
        bytes: result.bytes,
        suggestedName: _suggestedPdfName,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: $path')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final money = NumberFormat('#,##0.##', 'ru_RU');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Этикетка PDF'),
        actions: [
          IconButton(
            tooltip: 'Обновить предпросмотр',
            onPressed: _scheduleGenerate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Данные на этикетке',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            p.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Артикул: ${p.sku}', style: const TextStyle(fontSize: 16)),
                          if (p.price != null)
                            Text(
                              'Цена: ${money.format(p.price)} ${p.currencySymbol}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          if (p.warehouseCell != null && p.warehouseCell!.isNotEmpty)
                            Text(
                              'Ячейка: ${p.warehouseCell}',
                              style: const TextStyle(fontSize: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LabelSizePreset>(
                    value: _size,
                    decoration: const InputDecoration(
                      labelText: 'Размер этикетки',
                      border: OutlineInputBorder(),
                    ),
                    items: LabelSizePreset.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text('${e.widthMm}×${e.heightMm} мм'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _size = v);
                      _scheduleGenerate();
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _copiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Количество этикеток',
                      hintText: '1–99',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onSubmitted: (_) => _scheduleGenerate(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _scheduleGenerate,
                      child: const Text('Применить количество'),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Цена'),
                    value: _showPrice,
                    onChanged: (v) {
                      setState(() => _showPrice = v);
                      _scheduleGenerate();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Штрихкод CODE128'),
                    value: _showBarcode,
                    onChanged: (v) {
                      setState(() => _showBarcode = v);
                      _scheduleGenerate();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('QR-код'),
                    subtitle: const Text('Отключается для 50×30 мм'),
                    value: _showQr,
                    onChanged: (v) {
                      setState(() => _showQr = v);
                      _scheduleGenerate();
                    },
                  ),
                  if (p.warehouseCell != null && p.warehouseCell!.isNotEmpty)
                    SwitchListTile(
                      title: const Text('Показывать ячейку'),
                      value: _showCell,
                      onChanged: (v) {
                        setState(() => _showCell = v);
                        _scheduleGenerate();
                      },
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Предпросмотр',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 280,
                    child: FutureBuilder<LabelPdfResult>(
                      future: _resultFuture,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(child: Text('${snap.error}'));
                        }
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final r = snap.data!;
                        return PdfPreview(
                          build: (PdfPageFormat format) async => r.bytes,
                          initialPageFormat: r.pageFormat,
                          allowPrinting: false,
                          allowSharing: false,
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          useActions: false,
                          dynamicLayout: false,
                          maxPageWidth: MediaQuery.sizeOf(context).width - 32,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _print,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Печать'),
                    ),
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
