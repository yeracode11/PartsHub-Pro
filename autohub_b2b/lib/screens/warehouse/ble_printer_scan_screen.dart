import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/screens/warehouse/ble_printer_connected_screen.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';
import 'package:autohub_b2b/services/hardware/flutter_blue_adapter_resolve.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Поиск термопринтеров BLE и переход к подключению.
class BlePrinterScanScreen extends StatefulWidget {
  const BlePrinterScanScreen({super.key});

  @override
  State<BlePrinterScanScreen> createState() => _BlePrinterScanScreenState();
}

class _BlePrinterScanScreenState extends State<BlePrinterScanScreen> {
  final Map<DeviceIdentifier, ScanResult> _results = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<OnConnectionStateChangedEvent>? _connSub;
  bool _scanning = false;
  String? _error;
  /// Показывать только периферию с непустым именем (GAP / platform), без «голого» MAC/UUID.
  bool _onlyNamedDevices = false;

  @override
  void initState() {
    super.initState();
    _connSub = FlutterBluePlus.events.onConnectionStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _start();
  }

  @override
  void dispose() {
    _connSub?.cancel();
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
    final adapter = await fbpAwaitAdapterStateResolved();

    if (adapter == BluetoothAdapterState.turningOn) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }

    if (adapter == BluetoothAdapterState.off ||
        adapter == BluetoothAdapterState.turningOff ||
        adapter == BluetoothAdapterState.unauthorized ||
        adapter == BluetoothAdapterState.unavailable) {
      if (mounted) setState(() => _error = fbpAdapterStateHintRu(adapter));
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
      if (mounted) setState(() => _error = userFacingApiMessage(e));
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

  bool _hasName(ScanResult r) {
    final adv = r.advertisementData.advName.trim();
    final pname = r.device.platformName.trim();
    return pname.isNotEmpty || adv.isNotEmpty;
  }

  String _connectedTileTitle(BluetoothDevice d) {
    final sr = _results[d.remoteId];
    if (sr != null) return _displayName(sr);
    final pn = d.platformName.trim();
    if (pn.isNotEmpty) return pn;
    return d.remoteId.str;
  }

  String _connectedTileSubtitle(BluetoothDevice d) {
    final sr = _results[d.remoteId];
    final rssiPart = sr != null ? ' · RSSI ${sr.rssi}' : '';
    return '${d.remoteId.str}$rssiPart · активное соединение';
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
    final connected = [...FlutterBluePlus.connectedDevices];
    connected.sort(
      (a, b) =>
          _connectedTileTitle(a).toLowerCase().compareTo(_connectedTileTitle(b).toLowerCase()),
    );

    final connectedIds = connected.map((d) => d.remoteId).toSet();

    final all = _results.values.toList()
      ..sort((a, b) => _displayName(a).compareTo(_displayName(b)));

    final nameFiltered =
        _onlyNamedDevices ? all.where(_hasName).toList(growable: false) : all;

    final scanOnly = nameFiltered
        .where((r) => !connectedIds.contains(r.device.remoteId))
        .toList(growable: false);

    final nothingFound = scanOnly.isEmpty && connected.isEmpty;

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
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text(
                'Только с названием',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _onlyNamedDevices
                    ? 'Скрыты устройства без имени в рекламе или у системы.'
                    : 'Показаны все найденные BLE‑устройства.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.25,
                ),
              ),
              value: _onlyNamedDevices,
              onChanged: (v) => setState(() => _onlyNamedDevices = v),
              activeThumbColor: AppTheme.primaryColor,
            ),
          ),
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
            child: nothingFound && !_scanning
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _onlyNamedDevices && _results.isNotEmpty
                            ? 'Нет устройств с именем. Выключите фильтр или обновите сканирование.'
                            : 'Устройства не найдены. Нажмите обновить.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : nothingFound && _scanning
                    ? const Center(
                        child: Text(
                          'Поиск устройств…',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          if (scanOnly.isNotEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                                child: Text(
                                  'В эфире',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          if (scanOnly.isEmpty && !_scanning && connected.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                child: Text(
                                  'В текущем сканировании принтер не виден, но уже есть активное подключение — см. ниже.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final r = scanOnly[i];
                                final name = _displayName(r);
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i > 0) const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.print_outlined,
                                        color: AppTheme.primaryColor,
                                      ),
                                      title: Text(name),
                                      subtitle: Text(
                                        '${r.device.remoteId.str} · RSSI ${r.rssi}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      onTap: () => _openPrinter(r.device),
                                    ),
                                  ],
                                );
                              },
                              childCount: scanOnly.length,
                            ),
                          ),
                          if (connected.isNotEmpty) ...[
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.link, color: Colors.green, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Подключены к приложению',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final d = connected[i];
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (i > 0) const Divider(height: 1),
                                      ListTile(
                                        leading: const Icon(
                                          Icons.bluetooth_connected,
                                          color: Colors.green,
                                        ),
                                        title: Text(_connectedTileTitle(d)),
                                        subtitle: Text(
                                          _connectedTileSubtitle(d),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        trailing: const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 22,
                                        ),
                                        onTap: () => _openPrinter(d),
                                      ),
                                    ],
                                  );
                                },
                                childCount: connected.length,
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
