import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/label_product_model.dart';
import 'package:autohub_b2b/models/label_size_preset.dart';
import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';
import 'package:autohub_b2b/services/pdf/label_pdf_service.dart';
import 'package:autohub_b2b/services/print/label_print_service.dart';
import 'package:autohub_b2b/services/print/pdf_label_ble_print_service.dart';
import 'package:autohub_b2b/services/print/tspl_ble_label_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

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
  final _thermalWifi = ThermalPrinterService();
  final _copiesCtrl = TextEditingController(text: '1');

  LabelSizePreset _size = LabelSizePreset.mm60x40;
  bool _transposePhysical = false;
  bool _showPrice = true;
  bool _showBarcode = true;
  bool _showQr = true;
  bool _showCell = true;

  late Future<LabelPdfResult> _resultFuture;

  /// Не отправлять два потока одновременно.
  bool _bleSending = false;
  bool _wifiSending = false;
  bool _tsplSending = false;

  bool get _anyEscPosSending => _bleSending || _wifiSending || _tsplSending;

  bool get _mobileBle =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get _canNetworkEscPos => !kIsWeb;
  @override
  void initState() {
    super.initState();
    _showPrice = widget.product.showPrice;
    _showBarcode = widget.product.showBarcode;
    _showQr = widget.product.showQr;
    _showCell = widget.product.showWarehouseCell;
    _resultFuture = _generate();
    if (_canNetworkEscPos) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _thermalWifi.autoConnectToSavedPrinter();
        if (mounted) setState(() {});
      });
    }
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
      transposePhysical: _transposePhysical,
    );
  }

  void _scheduleGenerate() {
    setState(() {
      _resultFuture = _generate();
    });
  }

  String get _suggestedPdfName {
    final raw = widget.product.sku.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final w = _transposePhysical ? _size.heightMm : _size.widthMm;
    final h = _transposePhysical ? _size.widthMm : _size.heightMm;
    return 'label_${raw}_${w}x$h.pdf';
  }

  Future<void> _print() async {
    if (_anyEscPosSending) return;
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
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка'))),
      );
    }
  }

  Future<void> _printBle() async {
    if (!_mobileBle || _anyEscPosSending) return;

    setState(() => _bleSending = true);

    try {
      final ready = await BleThermalPrintCoordinator.ensureReadyForPrinting();
      if (!mounted) return;

      if (!ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Подключите термопринтер по BLE: Настройки принтера → Bluetooth LE.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await _resultFuture;
      final bytes = await PdfLabelBlePrintService.buildEscPosBytes(
        result,
        paperSize: PdfLabelBlePrintService.paperSizeForPageFormat(
          result.pageFormat,
        ),
      );

      await BleThermalPrintCoordinator.session.writeEscPosBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Этикетка отправлена на BLE‑принтер'),
          backgroundColor: Colors.green,
        ),
      );
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка BLE')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _bleSending = false);
    }
  }

  /// Печать через TSPL напрямую по BLE — без PDF-растрирования.
  /// Правильный протокол для AiYin IP-802BT.
  Future<void> _printTsplBle() async {
    if (!_mobileBle || _anyEscPosSending) return;

    setState(() => _tsplSending = true);
    try {
      final ready = await BleThermalPrintCoordinator.ensureReadyForPrinting();
      if (!mounted) return;

      if (!ready) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Подключите принтер: Настройки принтера → Bluetooth LE.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await TsplBleLabelService.printViaBle(
        _effectiveProduct(),
        copies: _parseCopies(),
        transposePhysical: _transposePhysical,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TSPL-этикетка отправлена на принтер'),
          backgroundColor: Colors.green,
        ),
      );
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка TSPL')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _tsplSending = false);
    }
  }

  Future<void> _printWifiEscPos() async {
    if (!_canNetworkEscPos || _anyEscPosSending) return;

    setState(() => _wifiSending = true);
    try {
      await _thermalWifi.autoConnectToSavedPrinter();
      if (!_thermalWifi.isWifi || _thermalWifi.wifiIp == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Укажите IP принтера в «Настройки принтера» → раздел Wi‑Fi и нажмите «Подключить».',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final result = await _resultFuture;
      final bytes = await PdfLabelBlePrintService.buildEscPosBytes(
        result,
        paperSize: PdfLabelBlePrintService.paperSizeForPageFormat(
          result.pageFormat,
        ),
      );

      final ok = await _thermalWifi.sendEscPosWifi(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Этикетка отправлена на ${_thermalWifi.wifiIp}:${_thermalWifi.wifiPort}'
                : 'Не удалось отправить данные по сети. Проверьте IP и порт 9100.',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка сети')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _wifiSending = false);
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
                  SwitchListTile(
                    title: const Text('Печать поперёк'),
                    subtitle: const Text(
                      'Меняются ширина и высота листа; предпросмотр совпадает с печатью.',
                    ),
                    value: _transposePhysical,
                    onChanged: (v) {
                      setState(() => _transposePhysical = v);
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Главная кнопка: TSPL BLE (AiYin IP-802BT)
                  if (_mobileBle) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      onPressed: _anyEscPosSending ? null : _printTsplBle,
                      icon: _tsplSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bluetooth_connected),
                      label: Text(_tsplSending ? 'Отправка TSPL…' : 'Печать BLE (TSPL)'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _anyEscPosSending ? null : _print,
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('PDF / AirPrint'),
                        ),
                      ),
                      if (_mobileBle) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _anyEscPosSending ? null : _printBle,
                            icon: _bleSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.image_outlined),
                            label: Text(_bleSending ? '…' : 'ESC/POS BLE'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_canNetworkEscPos) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _anyEscPosSending ? null : _printWifiEscPos,
                      icon: _wifiSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_outlined),
                      label: Text(
                        _wifiSending
                            ? 'Отправка…'
                            : (_thermalWifi.isWifi && _thermalWifi.wifiIp != null
                                ? 'Печать по сети (${_thermalWifi.wifiIp})'
                                : 'Печать по сети (ESC/POS)'),
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
