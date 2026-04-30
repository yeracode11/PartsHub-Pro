import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/screens/warehouse/ble_printer_connected_screen.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';

/// Поиск термопринтеров BLE и переход к подключению.
class BlePrinterScanScreen extends StatefulWidget {
  const BlePrinterScanScreen({super.key});

  @override
  State<BlePrinterScanScreen> createState() => _BlePrinterScanScreenState();
}

class _BlePrinterScanScreenState extends State<BlePrinterScanScreen> {
  final Map<DeviceIdentifier, ScanResult> _results = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    if (FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.stopScan();
    }
    super.dispose();
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    if (await Permission.location.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _start() async {
    await _ensurePermissions();
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      setState(() => _error = 'Включите Bluetooth');
      return;
    }

    setState(() {
      _error = null;
      _scanning = true;
      _results.clear();
    });

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((list) {
      if (!mounted) return;
      setState(() {
        for (final r in list) {
          _results[r.device.remoteId] = r;
        }
      });
    });

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 14),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  String _displayName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    final pname = r.device.platformName.trim();
    if (pname.isNotEmpty) return pname;
    if (adv.isNotEmpty) return adv;
    return r.device.remoteId.str;
  }

  Future<void> _openPrinter(BluetoothDevice dev) async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(BleThermalPrintCoordinator.prefsKeyLastDeviceId, dev.remoteId.str);
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlePrinterConnectedScreen(device: dev),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _results.values.toList()
      ..sort((a, b) => _displayName(a).compareTo(_displayName(b)));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Принтер Bluetooth LE'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Сканировать снова',
            onPressed: _scanning ? null : _start,
            icon: _scanning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              _error ??
                  'Выберите принтер из списка. Убедитесь, что он включён и в режиме сопряжения.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _error != null ? Colors.red : AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? 'Поиск устройств…' : 'Устройства не найдены. Нажмите обновить.',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = list[i];
                      final name = _displayName(r);
                      return ListTile(
                        leading: const Icon(Icons.print_outlined, color: AppTheme.primaryColor),
                        title: Text(name),
                        subtitle: Text(
                          '${r.device.remoteId.str} · RSSI ${r.rssi}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => _openPrinter(r.device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
