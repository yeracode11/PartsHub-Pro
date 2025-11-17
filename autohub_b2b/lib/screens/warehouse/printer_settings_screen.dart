import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';

/// Экран настроек принтера
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final ThermalPrinterService _printer = ThermalPrinterService();
  List<Map<String, dynamic>> _availablePrinters = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final printers = await _printer.getAvailableUSBPrinters();
      setState(() {
        _availablePrinters = printers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки принтеров: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _connectToPrinter(Map<String, dynamic> printer) async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Отключаемся от текущего принтера, если подключены
      if (_printer.isConnected) {
        await _printer.disconnect();
      }

      // Подключаемся к выбранному принтеру
      final connected = await _printer.connectUSB();

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        if (connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Подключено к принтеру: ${printer['name']}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось подключиться к принтеру'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printTestPage() async {
    if (!_printer.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала подключитесь к принтеру'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final success = await _printer.printTestPage();

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Тестовая страница отправлена на печать'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка печати тестовой страницы'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Настройки принтера'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadPrinters,
            tooltip: 'Обновить список',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Статус подключения
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Статус подключения',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                _printer.isConnected
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _printer.isConnected
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _printer.isConnected
                                    ? 'Подключено'
                                    : 'Не подключено',
                                style: TextStyle(
                                  color: _printer.isConnected
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_printer.isConnected && _printer.printerName != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Принтер: ${_printer.printerName}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Список доступных принтеров
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Доступные USB принтеры',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _isRefreshing ? null : _loadPrinters,
                                tooltip: 'Обновить',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_availablePrinters.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.print_disabled,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Принтеры не найдены',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Подключите USB принтер и нажмите "Обновить"',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ..._availablePrinters.map((printer) {
                              final isCurrentPrinter = _printer.isConnected &&
                                  _printer.printerName == printer['name'];
                              return ListTile(
                                leading: Icon(
                                  isCurrentPrinter
                                      ? Icons.check_circle
                                      : Icons.print,
                                  color: isCurrentPrinter
                                      ? Colors.green
                                      : AppTheme.primaryColor,
                                ),
                                title: Text(printer['name'] as String),
                                subtitle: Text(
                                  'VID: ${(printer['vendorId'] as int).toRadixString(16).toUpperCase()}, '
                                  'PID: ${(printer['productId'] as int).toRadixString(16).toUpperCase()}',
                                ),
                                trailing: isCurrentPrinter
                                    ? const Chip(
                                        label: Text('Подключено'),
                                        backgroundColor: Colors.green,
                                      )
                                    : ElevatedButton(
                                        onPressed: _isRefreshing
                                            ? null
                                            : () => _connectToPrinter(printer),
                                        child: const Text('Подключить'),
                                      ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Кнопка печати тестовой страницы
                  if (_printer.isConnected)
                    ElevatedButton.icon(
                      onPressed: _isRefreshing ? null : _printTestPage,
                      icon: const Icon(Icons.print),
                      label: const Text('Печать тестовой страницы'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

