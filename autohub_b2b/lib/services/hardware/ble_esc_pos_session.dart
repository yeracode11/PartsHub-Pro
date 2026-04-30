import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Thrown when BLE ESC/POS setup or write fails in a user-visible way.
class BleEscPosException implements Exception {
  BleEscPosException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'BleEscPosException: $message' : 'BleEscPosException: $message ($cause)';
}

/// Low-level BLE session for thermal printers that accept raw ESC/POS over GATT.
///
/// Для коммерческого использования может потребоваться лицензия [FlutterBluePlus](https://pub.dev/packages/flutter_blue_plus).
class BleEscPosSession {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _writeWithoutResponse = false;

  /// Часть прошивок **49535343…** после notify на TX обрывает сессию — при **true** notify не включаем.
  static bool skipCompanionNotifyForSsiUart4953 = false;

  BluetoothDevice? get device => _device;

  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  bool get isReady =>
      _device != null && _device!.isConnected && _writeCharacteristic != null;

  bool get writeUsesWithoutResponse => _writeWithoutResponse;

  int get mtuNow => _device?.mtuNow ?? 23;

  /// Пауза между ATT-чанками при `writeWithoutResponse` (иначе часть прошивок теряет поток).
  static const Duration defaultInterChunkDelay = Duration(milliseconds: 18);

  void _log(String msg) {
    debugPrint('[BleEscPos] $msg');
    developer.log(msg, name: 'BleEscPos');
  }

  void _logTopWriteCandidates(BluetoothDevice d) {
    final all = writableCharacteristicsExcludingBleMaintenance(d);
    if (all.isEmpty) return;
    all.sort(
      (a, b) => escPosWriteCharacteristicScore(b).compareTo(escPosWriteCharacteristicScore(a)),
    );
    final n = math.min(6, all.length);
    for (var i = 0; i < n; i++) {
      final c = all[i];
      _log(
        'Write cand #${i + 1} score=${escPosWriteCharacteristicScore(c)} '
        '${c.uuid.str} srv=${c.serviceUuid.str}',
      );
    }
  }

  static void logGattTree(BluetoothDevice d) {
    void logMsg(String m) {
      debugPrint('[BleEscPos] $m');
      developer.log(m, name: 'BleEscPos');
    }
    for (final s in d.servicesList) {
      logMsg('Service ${s.uuid.str}');
      for (final c in s.characteristics) {
        final p = c.properties;
        logMsg(
          '  Char ${c.uuid.str}  write=${p.write} writeNoResp=${p.writeWithoutResponse} '
          'read=${p.read} notify=${p.notify} indicate=${p.indicate}',
        );
      }
    }
  }

  static List<BluetoothCharacteristic> writableCharacteristicsExcludingBleMaintenance(
    BluetoothDevice d,
  ) {
    bool looksStdBleMaintenance(Guid su) {
      final x = su.str.toLowerCase().replaceAll('-', '');
      if (x.length < 8) return false;
      final short = x.substring(4, 8);
      return const {'180f', '180a', '1805'}.contains(short);
    }

    final candidates = <BluetoothCharacteristic>[];
    for (final s in d.servicesList) {
      if (looksStdBleMaintenance(s.uuid)) continue;
      for (final c in s.characteristics) {
        final p = c.properties;
        if (p.write || p.writeWithoutResponse) candidates.add(c);
      }
    }
    return candidates;
  }

  static int escPosWriteCharacteristicScore(BluetoothCharacteristic c) {
    var s = 0;
    final u = c.uuid.str.toLowerCase();
    if (u.contains('ae01')) s += 320;
    if (u.contains('6e400002')) s += 200;
    if (u.contains('ffe1')) s += 175;
    if (u.contains('fff1')) s += 165;
    if (u.contains('fff2')) s += 95;
    if (u.contains('49535343')) {
      s += 230;
      if (c.properties.writeWithoutResponse) s += 45;
    }
    if (u.contains('aec9') || u.contains('ffc1') || u.contains('ffc2')) {
      s += 55;
    }
    if (c.properties.write) s += 40;
    if (c.properties.writeWithoutResponse) s += 12;
    return s;
  }

  static ({BluetoothCharacteristic chr, bool withoutResponse})? pickEscPosWriteTarget(
    BluetoothDevice d,
  ) {
    final candidates = writableCharacteristicsExcludingBleMaintenance(d);
    if (candidates.isEmpty) return null;

    candidates.sort(
      (a, b) => escPosWriteCharacteristicScore(b).compareTo(escPosWriteCharacteristicScore(a)),
    );
    final best = candidates.first;
    final uBest = best.uuid.str.toLowerCase();
    final hasWith = best.properties.write;
    final hasWithout = best.properties.writeWithoutResponse;

    final bool withoutResponse;
    if (uBest.contains('ae01')) {
      withoutResponse = hasWithout ? true : (hasWith ? false : true);
    } else if (uBest.contains('49535343')) {
      withoutResponse = hasWithout ? true : (hasWith ? false : true);
    } else if (hasWith) {
      withoutResponse = false;
    } else {
      withoutResponse = hasWithout;
    }

    return (chr: best, withoutResponse: withoutResponse);
  }

  Future<void> connect(BluetoothDevice device) async {
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      throw BleEscPosException('Включите Bluetooth на устройстве.');
    }

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    _device = device;
    _writeCharacteristic = null;

    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 35),
        mtu: Platform.isAndroid ? 512 : null,
      );
    } on FlutterBluePlusException catch (e) {
      throw BleEscPosException('Не удалось подключиться к принтеру.', e);
    }

    if (Platform.isAndroid) {
      try {
        final mtu = await device.requestMtu(517);
        _log('Android MTU negotiated: $mtu');
      } catch (e) {
        _log('requestMtu skipped: $e');
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 520));
    }
    _log(
      'Connected; mtuNow=${device.mtuNow} advName=${device.advName} platformName=${device.platformName}',
    );
  }

  Future<void> discoverAndBindWriteCharacteristic() async {
    final d = _device;
    if (d == null || d.isDisconnected) {
      throw BleEscPosException('Принтер не подключён.');
    }

    try {
      await d.discoverServices(timeout: 30);
    } on FlutterBluePlusException catch (e) {
      throw BleEscPosException('Ошибка обнаружения сервисов BLE.', e);
    }

    logGattTree(d);
    _logTopWriteCandidates(d);
    final picked = pickEscPosWriteTarget(d);
    if (picked == null) {
      throw BleEscPosException(
        'Не найдена характеристика с записью (write / writeWithoutResponse). '
        'Смотрите логи сервисов выше.',
      );
    }

    _writeCharacteristic = picked.chr;
    _writeWithoutResponse = picked.withoutResponse;
    _log(
      'Using write char ${picked.chr.uuid.str} '
      'withoutResponse=$_writeWithoutResponse mtuNow=${d.mtuNow}',
    );

    await _ensurePrinterDataChannel(d, picked.chr);
  }

  Future<void> _ensurePrinterDataChannel(
    BluetoothDevice d,
    BluetoothCharacteristic writeChr,
  ) async {
    BluetoothService? svc;
    for (final s in d.servicesList) {
      if (s.uuid.str.toLowerCase() == writeChr.serviceUuid.str.toLowerCase()) {
        svc = s;
        break;
      }
    }
    if (svc == null) return;

    final wUuid = writeChr.uuid.str.toLowerCase();
    BluetoothCharacteristic? companion;

    if (wUuid.contains('ae01')) {
      for (final c in svc.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u.contains('ae02')) {
          companion = c;
          break;
        }
      }
    }

    if (companion == null && (wUuid.contains('fff1') || wUuid.contains('ffe1'))) {
      for (final c in svc.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u.contains('fff2') && (c.properties.notify || c.properties.indicate)) {
          companion = c;
          break;
        }
      }
    }

    if (companion == null && wUuid.contains('6e400002')) {
      for (final c in svc.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u.contains('6e400003')) {
          companion = c;
          break;
        }
      }
    }

    if (companion == null && wUuid.contains('49535343')) {
      for (final c in svc.characteristics) {
        final u = c.uuid.str.toLowerCase();
        if (u.contains('49535343') &&
            c.uuid.str.toLowerCase() != wUuid &&
            (c.properties.notify || c.properties.indicate)) {
          companion = c;
          break;
        }
      }
    }

    if (companion == null) {
      for (final c in svc.characteristics) {
        if (c.uuid.str == writeChr.uuid.str) continue;
        if (c.properties.notify || c.properties.indicate) {
          companion = c;
          break;
        }
      }
    }

    if (companion == null ||
        (!companion.properties.notify && !companion.properties.indicate)) {
      return;
    }

    final wLow = writeChr.uuid.str.toLowerCase();
    if (skipCompanionNotifyForSsiUart4953 && wLow.contains('49535343')) {
      _log(
        'Skipping companion notify (skipCompanionNotifyForSsiUart4953=true) '
        'for SSI/UART RX ${writeChr.uuid.str}',
      );
      return;
    }

    try {
      await companion.setNotifyValue(true, timeout: 20);
      _log('Enabled notify/indicate ${companion.uuid.str}');
      await Future<void>.delayed(const Duration(milliseconds: 220));
      _log('BLE link check: connected=${d.isConnected} mtu=${d.mtuNow}');
    } catch (e) {
      _log('Companion notify skipped: $e');
    }
  }

  int _maxPayloadBytes() {
    final mtu = math.max(23, mtuNow);
    var raw = math.max(20, math.min(mtu - 3, 512));
    if (Platform.isIOS) {
      raw = math.min(raw, 92);
    }
    return raw;
  }

  Future<void> _writeChunks(
    List<int> bytes, {
    required bool withoutResponse,
    required int chunkMax,
    required Duration interChunkDelay,
    required int writeTimeoutSec,
  }) async {
    final chr = _writeCharacteristic!;
    final total = bytes.length;
    if (total == 0) return;

    final step = math.max(1, chunkMax);
    final logStrideBytes = math.max(step * 32, math.min(8192, total ~/ 4));
    var lastLoggedEnd = 0;

    void logProgress(int i, int end, {required bool first}) {
      if (!first && end - lastLoggedEnd < logStrideBytes && end < total) return;
      final pct = (end * 100 / total).toStringAsFixed(0);
      _log(
        'Chunks $end / $total ($pct%), range $i–$end, noResp=$withoutResponse',
      );
      lastLoggedEnd = end;
    }

    _log(
      'Chunk stream start · $total B · chunk≤$step · delay=${interChunkDelay.inMilliseconds}ms',
    );

    for (var i = 0; i < bytes.length; i += step) {
      final end = math.min(i + step, bytes.length);
      final slice = bytes.sublist(i, end);
      try {
        await chr.write(
          slice,
          withoutResponse: withoutResponse,
          timeout: writeTimeoutSec,
        );
        logProgress(i, end, first: i == 0);
      } on FlutterBluePlusException catch (e) {
        _log('Chunk write failed at $i–$end / $total noResp=$withoutResponse: $e');
        throw BleEscPosException('Ошибка записи в принтер.', e);
      }
      if (end < bytes.length && interChunkDelay > Duration.zero) {
        await Future<void>.delayed(interChunkDelay);
      }
    }

    _log('Chunk stream done · $total B');
  }

  /// Сырой ESC/POS по BLE с разбиением на чанки.
  Future<void> writeEscPosBytes(
    List<int> bytes, {
    Duration interChunkDelay = defaultInterChunkDelay,
    int writeTimeoutSec = 30,
  }) async {
    final chr = _writeCharacteristic;
    final d = _device;
    if (chr == null || d == null || d.isDisconnected) {
      throw BleEscPosException('Принтер не готов к записи (нет соединения или характеристики).');
    }

    final chunkMax = _maxPayloadBytes();
    var mode = _writeWithoutResponse;
    _log(
      'Write → char ${chr.uuid.str} · srv ${chr.serviceUuid.str} · '
      'mtu=${d.mtuNow} · chunks≤$chunkMax · noResp(first)=$mode · ${bytes.length} B',
    );

    try {
      await _writeChunks(
        bytes,
        withoutResponse: mode,
        chunkMax: chunkMax,
        interChunkDelay: interChunkDelay,
        writeTimeoutSec: writeTimeoutSec,
      );
      return;
    } on BleEscPosException {
      final canFlip = chr.properties.write && chr.properties.writeWithoutResponse;
      if (!canFlip) {
        rethrow;
      }
      mode = !_writeWithoutResponse;
      _log('Retry full payload with alternating write mode noResp=$mode');
      await _writeChunks(
        bytes,
        withoutResponse: mode,
        chunkMax: chunkMax,
        interChunkDelay: interChunkDelay,
        writeTimeoutSec: writeTimeoutSec,
      );
    }
  }

  Future<void> disconnect() async {
    final d = _device;
    _writeCharacteristic = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    _device = null;
  }

  static Future<List<int>> buildTestReceiptBytes() async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final code128Data = '{BHELLO BLE'.split('');
    final bc = Barcode.code128(code128Data);

    return [
      ...g.reset(),
      ...g.text(
        'AutoHub / Auto+ Pro',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.emptyLines(1),
      ...g.text('BLE ESC/POS test', styles: const PosStyles(align: PosAlign.center)),
      ...g.hr(linesAfter: 1),
      ...g.barcode(bc, height: 72, width: 2, align: PosAlign.center),
      ...g.feed(1),
      ...g.qrcode(
        'https://example.com/ble-test',
        align: PosAlign.center,
        size: QRSize.size4,
      ),
      ...g.feed(2),
      ...g.text('Done.', styles: const PosStyles(align: PosAlign.center)),
      ...g.feed(2),
      ...g.cut(),
    ];
  }
}
