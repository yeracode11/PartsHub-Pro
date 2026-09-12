import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/services/hardware/flutter_blue_adapter_resolve.dart';

/// Общая BLE‑сессия ESC/POS: подключение сохраняется после выбора принтера.
class BleThermalPrintCoordinator {
  BleThermalPrintCoordinator._();

  static const prefsKeyLastDeviceId = 'ble_esc_pos_remote_id';

  static final BleEscPosSession _session = BleEscPosSession();

  static BleEscPosSession get session => _session;

  static Future<void> disconnect() => _session.disconnect();

  /// Уже подключено к сохранённому устройству или переподключение по id из настроек.
  static Future<bool> ensureReadyForPrinting() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(prefsKeyLastDeviceId);

    final dev = _session.device;
    if (dev != null && dev.isDisconnected) {
      await _session.disconnect();
    }

    if (_session.isReady) {
      if (savedId != null &&
          savedId.isNotEmpty &&
          _session.device!.remoteId.str.toLowerCase() != savedId.toLowerCase()) {
        await _session.disconnect();
      } else if (_session.isReady) {
        return true;
      }
    }

    final adapter = await fbpAwaitAdapterStateResolved();
    if (adapter == BluetoothAdapterState.off ||
        adapter == BluetoothAdapterState.turningOff ||
        adapter == BluetoothAdapterState.unauthorized ||
        adapter == BluetoothAdapterState.unavailable) {
      return false;
    }
    if (savedId == null || savedId.isEmpty) return false;

    try {
      final d = BluetoothDevice.fromId(savedId);
      await _session.connect(d);
      await _session.discoverAndBindWriteCharacteristic();
      return _session.isReady;
    } on BleEscPosException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
