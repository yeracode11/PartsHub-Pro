import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// На холодном старте экрана [FlutterBluePlus.adapterStateNow] нередко
/// равен [BluetoothAdapterState.unknown], хотя Bluetooth уже включён —
/// платформа ещё не прислала актуальный статус.
Future<BluetoothAdapterState> fbpAwaitAdapterStateResolved({
  Duration timeout = const Duration(seconds: 6),
}) async {
  final now = FlutterBluePlus.adapterStateNow;
  if (now != BluetoothAdapterState.unknown) {
    return now;
  }

  try {
    return await FlutterBluePlus.adapterState
        .where((s) => s != BluetoothAdapterState.unknown)
        .first
        .timeout(timeout);
  } on TimeoutException {
    return FlutterBluePlus.adapterStateNow;
  }
}

String fbpAdapterStateHintRu(BluetoothAdapterState s) {
  switch (s) {
    case BluetoothAdapterState.on:
      return '';
    case BluetoothAdapterState.off:
    case BluetoothAdapterState.turningOff:
      return 'Включите Bluetooth.';
    case BluetoothAdapterState.unauthorized:
      return 'Разрешите приложению доступ к Bluetooth в настройках системы.';
    case BluetoothAdapterState.turningOn:
      return 'Подождите, Bluetooth включается…';
    case BluetoothAdapterState.unavailable:
      return 'Bluetooth на этом устройстве недоступен.';
    case BluetoothAdapterState.unknown:
      return 'Не удалось определить состояние Bluetooth. Нажмите обновить или перезапустите приложение.';
  }
}
