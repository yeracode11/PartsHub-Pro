import 'package:esc_pos_printer_plus/esc_pos_printer_plus.dart';
import 'package:flutter/material.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/hardware/esc_pos_network_receipt_service.dart';
import 'package:autohub_b2b/services/hardware/printer_discovery_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';

/// Wi‑Fi subnet scan for port 9100 + one-tap connect + ESC/POS test receipt.
class PrinterDiscoveryScreen extends StatefulWidget {
  const PrinterDiscoveryScreen({super.key});

  @override
  State<PrinterDiscoveryScreen> createState() => _PrinterDiscoveryScreenState();
}

class _PrinterDiscoveryScreenState extends State<PrinterDiscoveryScreen> {
  final _discovery = PrinterDiscoveryService();
  final _thermal = ThermalPrinterService();

  final List<DiscoveredPrinterHost> _hosts = [];
  bool _scanning = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _subnetHint;
  String? _warning;
  String? _connectingIp;
  String? _testingIp;

  @override
  void dispose() {
    if (_scanning) _discovery.cancel();
    super.dispose();
  }

  Future<void> _findPrinters() async {
    setState(() {
      _scanning = true;
      _hosts.clear();
      _warning = null;
      _subnetHint = null;
      _progressDone = 0;
      _progressTotal = 0;
    });

    try {
      final result = await _discovery.discoverPrinters(
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _hosts
          ..clear()
          ..addAll(result.hosts);
        _subnetHint = result.deviceIpv4 != null
            ? 'Устройство: ${result.deviceIpv4} · ${result.subnetPrefix ?? 'подсеть'}'
            : null;
        _warning = result.warning;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _warning = userFacingApiMessage(e, prefix: 'Ошибка сканирования');
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _stopScan() {
    _discovery.cancel();
  }

  Future<void> _connect(DiscoveredPrinterHost host) async {
    setState(() => _connectingIp = host.ip);
    try {
      final ok = await _thermal.connectWifi(host.ip, port: host.port);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Подключено: ${host.ip}:${host.port}'
                : 'Не удалось подключиться: ${host.ip}',
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _connectingIp = null);
    }
  }

  Future<void> _testEscPos(DiscoveredPrinterHost host) async {
    setState(() => _testingIp = host.ip);
    try {
      final res = await EscPosNetworkReceiptService.printTestReceipt(
        host.ip,
        port: host.port,
      );
      if (!mounted) return;
      final ok = res == PosPrintResult.success;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Тест ESC/POS отправлен' : res.msg),
          backgroundColor: ok ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _testingIp = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Поиск Wi‑Fi принтеров'),
        actions: [
          if (_scanning)
            TextButton(
              onPressed: _stopScan,
              child: const Text('Стоп'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _scanning ? null : _findPrinters,
                  icon: _scanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_find),
                  label: Text(_scanning ? 'Сканирование…' : 'Найти принтеры'),
                ),
                if (_scanning && _progressTotal > 0) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progressDone / _progressTotal,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Проверка $_progressDone / $_progressTotal адресов',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (_subnetHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _subnetHint!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (_warning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _warning!,
                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _hosts.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? ''
                          : 'Нажмите «Найти принтеры»\n(порт 9100, подсеть по Wi‑Fi IPv4)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _hosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = _hosts[i];
                      final busyConnect = _connectingIp == h.ip;
                      final busyTest = _testingIp == h.ip;

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.print, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${h.ip}:${h.port}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  if (h.connectTime != null)
                                    Text(
                                      '${h.connectTime!.inMilliseconds} ms',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          busyConnect || busyTest
                                              ? null
                                              : () => _connect(h),
                                      child: busyConnect
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Подключить'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed:
                                          busyConnect || busyTest
                                              ? null
                                              : () => _testEscPos(h),
                                      child: busyTest
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Тест ESC/POS'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
