import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';
import 'package:autohub_b2b/services/print/tspl_ble_label_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

enum _Phase { idle, linking, ready, printing, error }

class _ProfileTestResult {
  _ProfileTestResult({required this.label, required this.status});
  final String label;
  final String status;
}

/// Подключение к выбранному BLE‑принтеру и тестовая ESC/POS печать.
/// Типичное «тихое» железо без печати при «BLE OK»: AiYin **IP‑802BT** — перебор профилей GATT.
class BlePrinterConnectedScreen extends StatefulWidget {
  const BlePrinterConnectedScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<BlePrinterConnectedScreen> createState() => _BlePrinterConnectedScreenState();
}

class _BlePrinterConnectedScreenState extends State<BlePrinterConnectedScreen> {
  BleEscPosSession get _session => BleThermalPrintCoordinator.session;

  _Phase _phase = _Phase.idle;
  String? _phaseDetail;
  String? _lastError;

  /// Результаты авто-теста всех профилей: uuid → статус.
  final List<_ProfileTestResult> _profileTestResults = [];

  @override
  void initState() {
    super.initState();
    _link();
  }

  String _statusDetailLine() {
    final mtu = widget.device.mtuNow;
    final u = _session.writeCharacteristic?.uuid.str ?? '—';
    final chan =
        _session.canCycleBleWriteProfile ? ' · ${_session.bleWriteProfileCaption}' : '';
    return 'MTU $mtu · $u$chan';
  }

  Future<void> _link() async {
    setState(() {
      _phase = _Phase.linking;
      _phaseDetail = 'Подключение и поиск канала записи…';
      _lastError = null;
    });

    try {
      if (_session.device?.remoteId == widget.device.remoteId && _session.isReady) {
        setState(() {
          _phase = _Phase.ready;
          _phaseDetail = _statusDetailLine();
        });
        return;
      }

      await _session.disconnect();
      await _session.connect(widget.device);
      await _session.discoverAndBindWriteCharacteristic();

      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _lastError = e.message;
        _phaseDetail = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _lastError = userFacingApiMessage(e);
        _phaseDetail = null;
      });
    }
  }

  Future<void> _printTest({required bool extended}) async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = extended ? 'Отправка расширенного чека…' : 'Отправка тестового чека…';
    });
    try {
      final bytes = extended
          ? await BleEscPosSession.buildExtendedTestReceiptBytes()
          : await BleEscPosSession.buildTestReceiptBytes();
      await _session.writeEscPosBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тест отправлен'), backgroundColor: Colors.green),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() {
        _phase = _Phase.ready;
        _lastError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e)), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    }
  }

  /// Тест TSPL — самый простой способ проверить, что принтер понимает TSPL.
  /// Если лента двигается — TSPL работает и это правильный канал.
  Future<void> _printTsplTest() async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = 'Отправка TSPL теста…';
    });
    try {
      await TsplBleLabelService.printTestViaBle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TSPL отправлен! Если лента напечатала «TSPL TEST» — всё работает.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка')), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _nakedLineFeed() async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = 'ESC @ + LF (6 байт)…';
    });
    try {
      await _session.writeEscPosBytes(BleEscPosSession.buildNakedLineFeedBytes());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Отправлено 6 байт (ESC@+LF). Если лента двинулась — ESC/POS работает. Если нет — этот UUID не тот канал.',
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.indigo,
        ),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e)), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _pulsePaperFeed() async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = 'Команды протяжки…';
    });
    try {
      await _session.writeEscPosBytes(BleEscPosSession.buildMinimalPaperFeedPulseBytes());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Команды протяга отправлены. Если был только короткий щёлчок — попробуйте другой профиль BLE: канал может принимать байты без разбора ESC/POS.',
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green.shade700,
        ),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e)), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    }
  }

  Future<void> _cycleBleWriteProfile() async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = 'Смена BLE‑канала записи…';
    });
    try {
      await _session.cycleBleWriteProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Другой UUID/сервис записи (см. профиль над кнопками). Запустите протяг или тест.',
          ),
          backgroundColor: Colors.teal,
        ),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } on BleEscPosException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e)), backgroundColor: Colors.red),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail = _statusDetailLine();
      });
    }
  }

  /// Авто-тест: шлёт 6 байт ESC@+LF на каждый профиль из пула по очереди,
  /// показывает какой UUID принял байты без ошибки (тот и нужно оставить).
  Future<void> _autoTestAllProfiles() async {
    final pool = _session.bleWriteProfilePool;
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пул профилей пуст — переподключитесь.')),
      );
      return;
    }

    setState(() {
      _phase = _Phase.printing;
      _profileTestResults.clear();
      _phaseDetail = 'Тестирование ${pool.length} профилей…';
    });

    final bytes = BleEscPosSession.buildNakedLineFeedBytes();

    for (var i = 0; i < pool.length; i++) {
      final chr = pool[i];
      final label = '${chr.uuid.str.substring(0, 8)} [${chr.serviceUuid.str.substring(0, 8)}]';

      if (!mounted) break;
      setState(() => _phaseDetail = 'Профиль ${i + 1}/${pool.length}: $label');

      // Переключаемся на нужный индекс через цикл.
      while (_session.bleWriteProfileIndex != i) {
        try {
          await _session.cycleBleWriteProfile();
        } catch (_) {
          break;
        }
      }

      String status;
      try {
        await _session.writeEscPosBytes(bytes, writeTimeoutSec: 6);
        status = '✅ OK — байты приняты GATT';
      } on BleEscPosException catch (e) {
        status = '❌ ${e.message}';
      } catch (e) {
        status = '❌ ${userFacingApiMessage(e)}';
      }

      if (!mounted) break;
      setState(() {
        _profileTestResults.add(_ProfileTestResult(label: label, status: status));
      });

      // Пауза: смотрим, зашевелилась ли лента.
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (!mounted) return;
    setState(() {
      _phase = _Phase.ready;
      _phaseDetail = _statusDetailLine();
    });
  }

  Future<void> _disconnectBle() async {
    await BleThermalPrintCoordinator.disconnect();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.device.platformName.trim().isEmpty
            ? widget.device.remoteId.str
            : widget.device.platformName;

    final busy = _phase == _Phase.linking || _phase == _Phase.printing;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_phase == _Phase.error) ...[
            Text(_lastError ?? 'Ошибка', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _link, child: const Text('Повторить')),
            const SizedBox(height: 24),
          ],
          if (busy && _phase != _Phase.error)
            Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_phaseDetail ?? '…'),
                ),
              ],
            ),
          if (!busy || _phase == _Phase.ready) ...[
            if (_phaseDetail != null && !busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _phaseDetail!,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            // ── TSPL (правильный протокол для AiYin IP-802BT) ──
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: (_phase == _Phase.ready) ? _printTsplTest : null,
              icon: const Icon(Icons.print_outlined),
              label: const Text('TSPL тест (AiYin IP-802BT)'),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Принтер AiYin IP-802BT использует TSPL, не ESC/POS.\n'
                'Если эта кнопка печатает — всё работает.',
                style: TextStyle(fontSize: 11, color: Colors.green.shade800, height: 1.4),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            // ── ESC/POS тесты (оставлены для других принтеров) ──
            OutlinedButton.icon(
              onPressed: (_phase == _Phase.ready) ? _nakedLineFeed : null,
              icon: const Icon(Icons.flash_on_outlined),
              label: const Text('6 байт ESC@+LF (не TSPL)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_phase == _Phase.ready) ? () => _printTest(extended: false) : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('ESC/POS тест (только текст)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_phase == _Phase.ready) ? _pulsePaperFeed : null,
              icon: const Icon(Icons.vertical_align_bottom_outlined),
              label: const Text('ESC/POS протяг ленты'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  (_phase == _Phase.ready && _session.canCycleBleWriteProfile)
                      ? _cycleBleWriteProfile
                      : null,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Следующий канал записи (ручной)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: (_phase == _Phase.ready) ? _autoTestAllProfiles : null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Авто-тест всех UUID (3 с на каждый)'),
            ),
            if (_profileTestResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Результаты авто-теста:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ..._profileTestResults.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          r.label,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          r.status,
                          style: TextStyle(
                            fontSize: 12,
                            color: r.status.startsWith('✅') ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Скопировать',
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '${r.label}: ${r.status}'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Профиль ✅ — байты приняты на уровне GATT. '
                'Если при этом лента двигалась — он и есть нужный канал ESC/POS.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _disconnectBle,
              icon: const Icon(Icons.link_off),
              label: const Text('Отключить и вернуться'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Если ни один UUID не двигает ленту:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. На Android: Настройки → О телефоне → 7 раз «Номер сборки» → '
                    'Параметры разработчика → «Журнал HCI Bluetooth» (включить).\n'
                    '2. Откройте официальное приложение AiYin, напечатайте что-нибудь.\n'
                    '3. Выключите журнал HCI.\n'
                    '4. Файл лога (btsnoop_hci.log) — через «Отчёты об ошибках» или /data/misc/bluetooth/ — '
                    'откройте в Wireshark: Filter → btle.data_header.length > 0.\n'
                    '5. Скопируйте первые пакеты Write на принтер — это и есть нужный UUID + протокол.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade800, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
