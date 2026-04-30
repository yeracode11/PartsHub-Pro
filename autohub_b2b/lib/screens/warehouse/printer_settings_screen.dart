import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/receipt_document_model.dart';
import 'package:autohub_b2b/screens/receipt/receipt_preview_screen.dart';
import 'package:autohub_b2b/screens/warehouse/ble_printer_scan_screen.dart';
import 'package:autohub_b2b/screens/warehouse/printer_discovery_screen.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final ThermalPrinterService _printer = ThermalPrinterService();

  List<Map<String, dynamic>> _systemPrinters = [];
  bool _isLoading = false;
  bool _isPrinting = false;
  bool _isConnectingWifi = false;
  String? _connectingAddress;

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9100');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    if (!Platform.isIOS) {
      await _printer.autoConnectToSavedPrinter();
      if (_printer.isWifi && _printer.wifiIp != null) {
        _ipController.text = _printer.wifiIp!;
        _portController.text = _printer.wifiPort.toString();
      }
      await _refresh();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      await _loadSystemPrinters();
    }
  }

  Future<void> _loadSystemPrinters() async {
    try {
      final printers = await _printer.getAvailableUSBPrinters();
      if (mounted) {
        setState(() {
          _systemPrinters = List<Map<String, dynamic>>.from(printers);
        });
      }
    } catch (_) {}
  }

  Future<void> _connectWifi() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showSnack('Введите IP-адрес принтера', Colors.orange);
      return;
    }
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    setState(() => _isConnectingWifi = true);
    try {
      final ok = await _printer.connectWifi(ip, port: port);
      if (mounted) {
        setState(() => _isConnectingWifi = false);
        _showSnack(
          ok ? 'Подключено к $ip:$port' : 'Не удалось подключиться к $ip:$port',
          ok ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnectingWifi = false);
        _showSnack('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _connectSystem(Map<String, dynamic> printer) async {
    setState(() => _connectingAddress = printer['name']);
    try {
      if (_printer.isConnected) await _printer.disconnect();
      final ok = await _printer.connectUSB(
        printerName: printer['name'] as String?,
        printerData: printer,
      );
      if (mounted) {
        setState(() => _connectingAddress = null);
        _showSnack(
          ok ? 'Подключено: ${printer['name']}' : 'Не удалось подключиться',
          ok ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _connectingAddress = null);
        _showSnack('Ошибка: $e', Colors.red);
      }
    }
  }

  Future<void> _disconnect() async {
    await _printer.disconnect(clearSettings: true);
    setState(() {});
    _showSnack('Принтер отключён', Colors.green);
  }

  Future<void> _testPrint() async {
    setState(() => _isPrinting = true);
    try {
      final ok = await _printer.printTestPage();
      if (mounted) {
        setState(() => _isPrinting = false);
        _showSnack(
          ok ? 'Тестовая страница отправлена' : 'Ошибка печати',
          ok ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        _showSnack('Ошибка: $e', Colors.red);
      }
    }
  }

  void _showSnack(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Настройки принтера'),
        actions: [
          if (!Platform.isIOS)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _refresh,
              tooltip: 'Обновить',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Platform.isIOS
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildBleThermalSection(context),
                    const SizedBox(height: 24),
                    _buildIosPdfReceiptSection(),
                    const SizedBox(height: 24),
                    _buildLabelPrintInfoCard(),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildBleThermalSection(context),
                      const SizedBox(height: 24),
                      _buildStatusCard(),
                      const SizedBox(height: 24),
                      _buildWifiSection(),
                      const SizedBox(height: 24),
                      _buildLabelPrintInfoCard(),
                      const SizedBox(height: 24),
                      if (_systemPrinters.isNotEmpty) ...[
                        _buildSystemPrintersSection(),
                        const SizedBox(height: 24),
                      ],
                      if (_printer.isConnected) _buildTestButton(),
                    ],
                  ),
                ),
    );
  }

  /// Термопринтер по Bluetooth Low Energy (Android / iPhone).
  Widget _buildBleThermalSection(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bluetooth, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Термопринтер по Bluetooth LE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Поиск и подключение к принтеру с ESC/POS по BLE (частые китайские POS‑модули AiYin, Nordic UART '
              'и др.). После подключения доступна тестовая печать на экране устройства.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.radar),
                label: const Text('Найти и подключить BLE‑принтер'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const BlePrinterScanScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// На iOS печать этикеток через TCP не используется — только PDF и системная печать (AirPrint).
  Widget _buildIosPdfReceiptSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Чеки и счета (PDF)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'На iPhone печать идёт как в маркетплейсах: формируется PDF, вы открываете предпросмотр, '
              'затем «Печать» (AirPrint — любой принтер в сети) или «Поделиться» (WhatsApp, Telegram, Файлы).',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  ReceiptPreviewScreen.open(
                    context,
                    ReceiptDocumentData.sample(),
                  );
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Открыть пример чека'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Готовый чек по заказу: экран заказа → иконка PDF в панели сверху.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ========================== Status Card ==========================

  Widget _buildLabelPrintInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.label_outline, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Этикетки PDF (50×30, 60×40, 100×150 мм) печатаются из карточки товара: '
                'Склад → товар → «Этикетка PDF».',
                style: TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final connected = _printer.isConnected;
    final name = _printer.printerName;
    final status = _printer.getPrinterStatus();
    final isWifi = status['isWifi'] == true;

    String connectionLabel = '';
    if (isWifi) {
      connectionLabel = ' (WiFi)';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: connected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    connected ? Icons.print : Icons.print_disabled,
                    color: connected ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connected ? 'Принтер подключён' : 'Принтер не подключён',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (connected && name != null)
                        Text(
                          '$name$connectionLabel',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                if (connected)
                  TextButton(
                    onPressed: _disconnect,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Отключить'),
                  ),
              ],
            ),
            if (!connected)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  Platform.isIOS
                      ? 'Подключите принтер по WiFi (введите IP-адрес ниже).'
                      : Platform.isAndroid
                          ? 'Подключитесь по WiFi (TCP) или печатайте этикетки PDF из карточки товара.'
                          : 'Выберите принтер из списка ниже.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================== WiFi Section ==========================

  Widget _buildWifiSection() {
    final isWifiConnected = _printer.isConnected && _printer.isWifi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'WiFi-принтер (TCP)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          Platform.isIOS
              ? 'Для Xprinter на iOS используйте подключение по WiFi.\nПринтер и телефон должны быть в одной WiFi-сети.'
              : 'Подключение к принтеру по WiFi (порт 9100).\nПринтер и устройство должны быть в одной сети.',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Card(
          color: isWifiConnected ? Colors.green.shade50 : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'IP-адрес',
                          hintText: '192.168.1.100',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.router, size: 20),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        enabled: !isWifiConnected,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Порт',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        enabled: !isWifiConnected,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => const PrinterDiscoveryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.wifi_find, size: 20),
                    label: const Text('Найти принтеры в сети'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isWifiConnected
                      ? Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Подключён',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          onPressed: _isConnectingWifi ? null : _connectWifi,
                          icon: _isConnectingWifi
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi),
                          label: Text(_isConnectingWifi ? 'Подключение...' : 'Подключить по WiFi'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================== System Printers ==========================

  Widget _buildSystemPrintersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.usb, color: AppTheme.textSecondary, size: 20),
            SizedBox(width: 8),
            Text('Системные принтеры', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ..._systemPrinters.map((printer) {
          final isCurrent = _printer.isConnected && _printer.printerName == printer['name'];
          final isConnecting = _connectingAddress == printer['name'];

          return Card(
            color: isCurrent ? Colors.green.shade50 : null,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                isCurrent ? Icons.check_circle : Icons.print,
                color: isCurrent ? Colors.green : AppTheme.primaryColor,
              ),
              title: Text(
                printer['name'] ?? 'Принтер',
                style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
              ),
              subtitle: Text(
                isCurrent
                    ? 'Подключён'
                    : (printer['connectionType'] ?? printer['url'] ?? ''),
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent ? Colors.green : AppTheme.textSecondary,
                ),
              ),
              trailing: isCurrent
                  ? const Icon(Icons.check, color: Colors.green)
                  : isConnecting
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : ElevatedButton(
                          onPressed: () => _connectSystem(printer),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Подключить'),
                        ),
            ),
          );
        }),
      ],
    );
  }

  // ========================== Test Button ==========================

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isPrinting ? null : _testPrint,
        icon: _isPrinting
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.print),
        label: Text(_isPrinting ? 'Печать...' : 'Тестовая печать'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      ),
    );
  }
}
