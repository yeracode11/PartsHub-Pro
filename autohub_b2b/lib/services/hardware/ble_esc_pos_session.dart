import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';

import 'package:autohub_b2b/services/hardware/flutter_blue_adapter_resolve.dart';

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
/// **AiYin IP‑802BT** (`IP-802BT_3801_BLE` и др.): в типичном GATT несколько транспортов — ISS UART
/// `49535343-fe7d…` (часто основной текстовый тракт через **`49535343-6daa…`**, рядом **`8841`**),
/// плюс «простые последовательные» **`fee7`/`fec7`**, **`fff0`/`fff2`**, **`ff00`/`ff02`**, **`18f0`/`2af1`**,
/// **`ff80`/`ff82`**. Если на ISS только щелчок без ленты, цикл профилей: [cycleBleWriteProfile].
///
/// Для коммерческого использования может потребоваться лицензия [FlutterBluePlus](https://pub.dev/packages/flutter_blue_plus).
class BleEscPosSession {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _writeWithoutResponse = false;

  /// Все найденные write‑характеристики после discover, порядок: лучшие по счёту первыми; активный профиль через [cycleBleWriteProfile].
  List<BluetoothCharacteristic> _bleWriteProfilePool = [];
  int _bleWriteProfileIndex = 0;

  /// Часть прошивок **49535343…** после notify на TX обрывает сессию — при **true** notify не включаем.
  static bool skipCompanionNotifyForSsiUart4953 = false;

  BluetoothDevice? get device => _device;

  BluetoothCharacteristic? get writeCharacteristic => _writeCharacteristic;

  bool get isReady =>
      _device != null && _device!.isConnected && _writeCharacteristic != null;

  bool get writeUsesWithoutResponse => _writeWithoutResponse;

  /// Циклически перебираются все подходящие UUID записи см. [bleWriteProfileCaption].
  bool get canCycleBleWriteProfile => _bleWriteProfilePool.length > 1;

  String get bleWriteProfileCaption {
    final n = _bleWriteProfilePool.length;
    if (n <= 1) return '';
    return 'профиль ${_bleWriteProfileIndex + 1}/$n';
  }

  /// Полный пул write-характеристик (для ручного перебора / авто-теста).
  List<BluetoothCharacteristic> get bleWriteProfilePool =>
      List.unmodifiable(_bleWriteProfilePool);

  int get bleWriteProfileIndex => _bleWriteProfileIndex;

  int get mtuNow => _device?.mtuNow ?? 23;

  /// Пауза между ATT-чанками при `writeWithoutResponse` (иначе часть прошивок теряет поток).
  static const Duration defaultInterChunkDelay = Duration(milliseconds: 18);

  /// При подтверждённом по ATT большом MTU MCU UART часто ограничен — режем ниже этого значения для ISS‑модуля.
  static const int issuartBleSafeChunkCeilBytes = 40;

  /// WoR без ATT‑ACK для ISSC UART («49535343…»): 18 ms часто сливают мост принтера под нагрузкой.
  static const Duration issuartWorMinimumInterChunkDelay = Duration(milliseconds: 52);

  /// Запись **с ответом** уже подтверждена по ATT, но UART‑мост к головке всё ещё ограничен —
  /// слишком короткая пауза между крупными чанками даёт «BLE OK», пустую ленту.
  static const Duration issuartAckMinimumInterChunkDelay = Duration(milliseconds: 30);

  /// После последнего чанка даём времени докачать байты в MCU принтера.
  static const Duration issuartUartDrainTailDelay = Duration(milliseconds: 160);

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

  static bool inferPreferWithoutResponse(BluetoothCharacteristic chr) {
    final uBest = chr.uuid.str.toLowerCase();
    final hasWith = chr.properties.write;
    final hasWithout = chr.properties.writeWithoutResponse;

    if (uBest.contains('ae01')) {
      return hasWithout ? true : (hasWith ? false : true);
    }
    // ISS UART (49535343-6daa и др.): прошивка отвечает на ATT‑запись — используем write+response.
    if (uBest.contains('49535343')) {
      return hasWith ? false : hasWithout;
    }
    // Для dual-mode (и write, и writeNoResp) за пределами ISS/ae01:
    // прошивки таких принтеров нередко «принимают» ATT write request, но не отвечают ACK → таймаут 30 с.
    // Безопаснее writeNoResp: нет таймаута, меньше блокировок UI.
    if (hasWith && hasWithout) {
      return true;
    }
    if (hasWith) {
      return false;
    }
    return hasWithout;
  }

  static int escPosWriteCharacteristicScore(BluetoothCharacteristic c) {
    var s = 0;
    final u = c.uuid.str.toLowerCase();
    final svcFlat = c.serviceUuid.str.toLowerCase().replaceAll('-', '');
    if (u.contains('ae01')) s += 320;
    if (u.contains('6e400002')) s += 200;
    if (u.contains('ffe1')) s += 175;
    if (u.contains('fff1')) s += 165;
    if (u.contains('fff2')) s += 95;
    if (u.contains('49535343')) {
      s += 215;
      if (c.properties.write) {
        s += 95;
      }
      // IP-802BT / ISSC: длинное поле данных на чипах Silicon Labs почти всегда `49535343-6daa-…`;
      // `8841` при том же сервисе часто вторичный, но набрал бы больший счёт из‑за writeWithoutResponse.
      if (u.contains('49535343-6daa')) {
        s += 175;
      } else if (u.contains('49535343-8841')) {
        s -= 40;
      }
    }
    if (u.contains('aec9') || u.contains('ffc1') || u.contains('ffc2')) {
      s += 55;
    }
    if (svcFlat.endsWith('fee7') && u.replaceAll('-', '').contains('fec7')) {
      s += 245;
    }
    if (svcFlat.endsWith('fff0') && u.contains('fff2')) {
      s += 210;
    }
    if (svcFlat.endsWith('ff00') && u.contains('ff02')) {
      s += 212;
    }
    if (svcFlat.endsWith('ff80') && u.contains('ff82')) {
      s += 212;
    }
    if (svcFlat.endsWith('18f0') && u.contains('2af1')) {
      s += 212;
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
    return (chr: best, withoutResponse: inferPreferWithoutResponse(best));
  }

  Future<void> connect(BluetoothDevice device) async {
    final adapter = await fbpAwaitAdapterStateResolved();
    if (adapter == BluetoothAdapterState.off || adapter == BluetoothAdapterState.turningOff) {
      throw BleEscPosException('Включите Bluetooth на устройстве.');
    }
    if (adapter == BluetoothAdapterState.unauthorized) {
      throw BleEscPosException(
        'Разрешите приложению доступ к Bluetooth в настройках телефона.',
      );
    }
    if (adapter == BluetoothAdapterState.unavailable) {
      throw BleEscPosException('Bluetooth на этом устройстве недоступен.');
    }

    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    _device = device;
    _writeCharacteristic = null;
    _bleWriteProfilePool.clear();
    _bleWriteProfileIndex = 0;

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
    _populateBleWriteProfilePool(d, picked.chr);
    _log(
      'Using write char ${picked.chr.uuid.str} '
      'write=${picked.chr.properties.write} writeNoResp=${picked.chr.properties.writeWithoutResponse} '
      'withoutResponse=$_writeWithoutResponse mtuNow=${d.mtuNow}',
    );

    await _ensurePrinterDataChannel(d, picked.chr);
  }

  void _populateBleWriteProfilePool(BluetoothDevice d, BluetoothCharacteristic picked) {
    _bleWriteProfilePool.clear();
    _bleWriteProfileIndex = 0;

    final all = writableCharacteristicsExcludingBleMaintenance(d)
      ..sort((a, b) => escPosWriteCharacteristicScore(b).compareTo(escPosWriteCharacteristicScore(a)));

    final seenKeys = <String>{};
    final orderedUnique = <BluetoothCharacteristic>[];
    for (final chr in all) {
      final k = '${chr.serviceUuid.str.toLowerCase()}@${chr.uuid.str.toLowerCase()}';
      if (seenKeys.contains(k)) {
        continue;
      }
      seenKeys.add(k);
      orderedUnique.add(chr);
    }

    final pickKey = '${picked.serviceUuid.str.toLowerCase()}@${picked.uuid.str.toLowerCase()}';
    final startIdx = orderedUnique.indexWhere(
      (c) => '${c.serviceUuid.str.toLowerCase()}@${c.uuid.str.toLowerCase()}' == pickKey,
    );

    _bleWriteProfilePool =
        startIdx <= 0 ? orderedUnique : [...orderedUnique.sublist(startIdx), ...orderedUnique.sublist(0, startIdx)];

    _log(
      'BLE записываемые профили (${_bleWriteProfilePool.length}): '
      '${_bleWriteProfilePool.map((c) => '${c.uuid.str}[${c.serviceUuid.str}]').join(' | ')}',
    );
  }

  /// IP‑802BT и аналоги: ESC/POS может уходить в **fec7**/**fff2**/…, хотя ACK на ISS уже «ОК».
  Future<void> cycleBleWriteProfile() async {
    final d = _device;
    if (d == null || d.isDisconnected) {
      throw BleEscPosException('Принтер не подключён.');
    }
    if (_bleWriteProfilePool.length < 2) {
      throw BleEscPosException('Нашёлся только один канал записи на устройстве.');
    }

    _bleWriteProfileIndex = (_bleWriteProfileIndex + 1) % _bleWriteProfilePool.length;
    final chr = _bleWriteProfilePool[_bleWriteProfileIndex];
    _writeCharacteristic = chr;
    _writeWithoutResponse = inferPreferWithoutResponse(chr);

    _log(
      'BLE профиль ${_bleWriteProfileIndex + 1}/${_bleWriteProfilePool.length}: '
      '${chr.uuid.str} srv=${chr.serviceUuid.str} '
      'write=${chr.properties.write} writeNoResp=${chr.properties.writeWithoutResponse} '
      'chosenNoResp=$_writeWithoutResponse mtu=${d.mtuNow}',
    );

    await _ensurePrinterDataChannel(d, chr);
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

  bool _isIssUartLike(BluetoothCharacteristic chr) {
    final c = chr.uuid.str.toLowerCase().replaceAll('-', '');
    final s = chr.serviceUuid.str.toLowerCase().replaceAll('-', '');
    return c.contains('49535343') || s.contains('49535343');
  }

  Duration _effectiveInterChunkDelay(
    BluetoothCharacteristic chr,
    bool withoutResp,
    Duration base,
  ) {
    if (!_isIssUartLike(chr)) return base;

    if (withoutResp) {
      final ms =
          math.max(base.inMilliseconds, issuartWorMinimumInterChunkDelay.inMilliseconds);
      if (ms != base.inMilliseconds) {
        _log(
          'ISS UART: extend WoR inter-chunk delay → ${ms}ms (was ${base.inMilliseconds}ms)',
        );
      }
      return Duration(milliseconds: ms);
    }

    final msAck =
        math.max(base.inMilliseconds, issuartAckMinimumInterChunkDelay.inMilliseconds);
    if (msAck != base.inMilliseconds) {
      _log(
        'ISS UART: floor write‑with‑response inter-chunk delay → ${msAck}ms (was ${base.inMilliseconds}ms)',
      );
    }
    return Duration(milliseconds: msAck);
  }

  Future<void> _issUartDrainTail(BluetoothCharacteristic chr) async {
    if (!_isIssUartLike(chr)) return;
    await Future<void>.delayed(issuartUartDrainTailDelay);
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
  ///
  /// Если текущая характеристика не отвечает (таймаут / дисконнект), автоматически
  /// пробуется следующий профиль из [_bleWriteProfilePool] (до исчерпания всех вариантов).
  Future<void> writeEscPosBytes(
    List<int> bytes, {
    Duration interChunkDelay = defaultInterChunkDelay,
    int writeTimeoutSec = 8,
  }) async {
    if (_writeCharacteristic == null || _device == null) {
      throw BleEscPosException('Принтер не готов к записи (нет соединения или характеристики).');
    }

    // Пробуем текущий профиль, при ошибке автоматически листаем дальше.
    final poolSize = _bleWriteProfilePool.isEmpty ? 1 : _bleWriteProfilePool.length;
    BleEscPosException? lastErr;

    for (var attempt = 0; attempt < poolSize; attempt++) {
      final chr = _writeCharacteristic!;
      final d = _device!;

      if (d.isDisconnected) {
        throw BleEscPosException('Принтер отключился во время передачи данных.');
      }

      final chunkMaxBase = _maxPayloadBytes();
      var chunkMax = chunkMaxBase;
      if (_isIssUartLike(chr)) {
        final safe = math.min(chunkMax, issuartBleSafeChunkCeilBytes);
        if (safe < chunkMax) {
          _log('ISS UART: cap chunk payload $chunkMax→$safe (переполнение UART FIFO)');
          chunkMax = safe;
        }
      }
      final mode = _writeWithoutResponse;
      _log(
        '[attempt ${attempt + 1}/$poolSize] Write → char ${chr.uuid.str} · srv ${chr.serviceUuid.str} · '
        'mtu=${d.mtuNow} · chunks≤$chunkMax · noResp=$mode · ${bytes.length} B',
      );

      final dualMode = chr.properties.write && chr.properties.writeWithoutResponse;

      Future<void> run(bool withoutResp) async {
        final delay = _effectiveInterChunkDelay(chr, withoutResp, interChunkDelay);
        await _writeChunks(
          bytes,
          withoutResponse: withoutResp,
          chunkMax: chunkMax,
          interChunkDelay: delay,
          writeTimeoutSec: writeTimeoutSec,
        );
      }

      try {
        if (dualMode) {
          BleEscPosException? dualErr;
          for (final withoutResp in <bool>[mode, !mode]) {
            try {
              await run(withoutResp);
              await _issUartDrainTail(chr);
              _log('BLE write OK noResp=$withoutResp mtu=${d.mtuNow} (dual char, attempt ${attempt + 1})');
              return;
            } on BleEscPosException catch (e) {
              dualErr = e;
              _log('BLE write attempt noResp=$withoutResp failed: ${e.message}');
            }
          }
          throw dualErr!;
        } else {
          await run(mode);
          await _issUartDrainTail(chr);
          _log('BLE write OK noResp=$mode mtu=${d.mtuNow} (attempt ${attempt + 1})');
          return;
        }
      } on BleEscPosException catch (e) {
        lastErr = e;
        _log('Profile ${_bleWriteProfileIndex + 1}/$poolSize failed: ${e.message}');
        if (attempt + 1 < poolSize) {
          // Автоматически переключаем на следующий профиль и пробуем снова.
          try {
            await cycleBleWriteProfile();
          } catch (_) {
            // Если нет других профилей — выходим.
            break;
          }
        }
      }
    }

    throw lastErr ?? BleEscPosException('Не удалось отправить данные на принтер.');
  }

  Future<void> disconnect() async {
    final d = _device;
    _writeCharacteristic = null;
    _bleWriteProfilePool.clear();
    _bleWriteProfileIndex = 0;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    _device = null;
  }

  /// Ультраминимальные байты: ESC @ (сброс) + несколько LF + одна ASCII-строка.
  /// Если принтер реагирует хотя бы протяжкой/щелчком — канал ESC/POS работает.
  static List<int> buildNakedLineFeedBytes() {
    const lf = 0x0a;
    const esc = 0x1b;
    return <int>[
      esc, 0x40, // ESC @ — сброс принтера
      ...'>TEST<'.codeUnits,
      lf, lf, lf, lf,
    ];
  }

  /// Компактная «тяжёлая» простейка ESC/POS: часть профилей на нажимает мотор лишь на «тиск» без
  /// печатаемой строки в буфере; добавляем текст, [ESC d] и [ESC J] протяг точками.
  static List<int> buildMinimalPaperFeedPulseBytes() {
    const lf = 0x0a;
    const cr = 0x0d;
    const esc = 0x1b;
    return <int>[
      esc, 0x40, // ESC @
      lf, lf,
      ...'-'.codeUnits,
      lf,
      ...'AUTOHUB PULSE'.codeUnits,
      cr, lf,
      esc, 0x64, 28, // ESC d — протяг N строк после вывода
      esc, 0x4a, 200, // ESC J — протяг ~200 точек вертикали
      esc, 0x4a, 200,
      esc, 0x64, 15,
      lf,
      lf,
      lf,
      lf,
      lf,
    ];
  }

  /// Минимальный тест только ASCII-текст + линии + отрез: часть прошивок не понимает
  /// штрихкод/GS‑QR поверх BLE и «молчит», хотя приложение не получает ошибку GATT.
  static Future<List<int>> buildTestReceiptBytes() async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    return [
      ...g.reset(),
      ...g.text(
        'AutoHub / Auto+ Pro',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.feed(1),
      ...g.text(
        'BLE ESC/POS test OK',
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.text(
        stamp,
        styles: const PosStyles(align: PosAlign.center),
      ),
      ...g.hr(linesAfter: 1),
      ...g.text(
        'Minimal test: text only.',
        styles: const PosStyles(align: PosAlign.left),
      ),
      ...g.feed(3),
      ...g.cut(),
    ];
  }

  /// Расширенный прогон GS (штрихкод + QR) — если простой тест уже печатается.
  static Future<List<int>> buildExtendedTestReceiptBytes() async {
    final profile = await CapabilityProfile.load();
    final g = Generator(PaperSize.mm80, profile);
    final code128Data = '{BHELLO BLE'.split('');
    final bc = Barcode.code128(code128Data);
    final stamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    return [
      ...g.reset(),
      ...g.text(
        'AutoHub / Auto+ Pro',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      ...g.emptyLines(1),
      ...g.text(stamp, styles: const PosStyles(align: PosAlign.center)),
      ...g.hr(linesAfter: 1),
      ...g.barcode(bc, height: 72, width: 2, align: PosAlign.center),
      ...g.feed(1),
      ...g.qrcode(
        'https://example.com/ble-test',
        align: PosAlign.center,
        size: QRSize.size4,
      ),
      ...g.feed(2),
      ...g.text('Extended test done.', styles: const PosStyles(align: PosAlign.center)),
      ...g.feed(2),
      ...g.cut(),
    ];
  }
}
