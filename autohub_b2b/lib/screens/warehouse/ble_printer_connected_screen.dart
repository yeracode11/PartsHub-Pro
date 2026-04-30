import 'package:flutter/material.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/hardware/ble_esc_pos_session.dart';
import 'package:autohub_b2b/services/hardware/ble_thermal_print_coordinator.dart';

enum _Phase { idle, linking, ready, printing, error }

/// Подключение к выбранному BLE‑принтеру и тестовая ESC/POS печать.
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

  @override
  void initState() {
    super.initState();
    _link();
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
          _phaseDetail = 'MTU ${widget.device.mtuNow} · ${ _session.writeCharacteristic?.uuid.str ?? "—"}';
        });
        return;
      }

      await _session.disconnect();
      await _session.connect(widget.device);
      await _session.discoverAndBindWriteCharacteristic();

      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail =
            'MTU ${widget.device.mtuNow} · характеристика ${_session.writeCharacteristic?.uuid.str ?? "—"}';
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
        _lastError = '$e';
        _phaseDetail = null;
      });
    }
  }

  Future<void> _printTest() async {
    setState(() {
      _phase = _Phase.printing;
      _phaseDetail = 'Отправка тестового чека…';
    });
    try {
      final bytes = await BleEscPosSession.buildTestReceiptBytes();
      await _session.writeEscPosBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тест отправлен'), backgroundColor: Colors.green),
      );
      setState(() {
        _phase = _Phase.ready;
        _phaseDetail =
            'MTU ${widget.device.mtuNow} · ${_session.writeCharacteristic?.uuid.str ?? "—"}';
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
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
      setState(() => _phase = _Phase.ready);
    }
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
            FilledButton.icon(
              onPressed: (_phase == _Phase.ready) ? _printTest : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Тестовая ESC/POS печать'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : _disconnectBle,
              icon: const Icon(Icons.link_off),
              label: const Text('Отключить и вернуться'),
            ),
            const SizedBox(height: 24),
            Text(
              'Если после подключения принтер не печатает, в логах Xcode/Logcat есть дерево '
              'GATT ([BleEscPos]). Для SSI‑UART пробуйте статический флаг '
              'BleEscPosSession.skipCompanionNotifyForSsiUart4953.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}
