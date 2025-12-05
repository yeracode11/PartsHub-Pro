import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/services/hardware/thermal_printer_service.dart';

/// Экран настроек принтера (для продакшена)
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
  Map<String, dynamic> _printerStatus = {};

  @override
  void initState() {
    super.initState();
    _initializePrinter();
  }

  /// Инициализация: автоподключение и загрузка принтеров
  Future<void> _initializePrinter() async {
    setState(() {
      _isLoading = true;
    });

    // Попытка автоподключения к сохраненному принтеру
    await _printer.autoConnectToSavedPrinter();
    
    // Обновляем статус
    _updatePrinterStatus();
    
    // Загружаем список доступных принтеров
    await _loadPrinters();
    
    setState(() {
      _isLoading = false;
    });
  }

  /// Обновление статуса принтера
  void _updatePrinterStatus() {
    setState(() {
      _printerStatus = _printer.getPrinterStatus();
    });
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await _printer.getAvailableUSBPrinters();
      setState(() {
        _availablePrinters = printers;
      });
    } catch (e) {
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
      final connected = await _printer.connectUSB(
        printerName: printer['name'] as String?,
        printerData: printer,
      );

      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        
        _updatePrinterStatus();

        if (connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Подключено: ${printer['name']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Не удалось подключиться к принтеру'),
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

  /// Отвязать принтер
  Future<void> _unbindPrinter() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отвязать принтер?'),
        content: Text(
          'Принтер "${_printerStatus['printerName']}" будет отключен.\n\n'
          'Настройки будут удалены, но вы сможете подключиться снова.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Отвязать'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isRefreshing = true;
      });

      await _printer.disconnect(clearSettings: true);
      
      setState(() {
        _isRefreshing = false;
      });
      
      _updatePrinterStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Принтер отвязан'),
            backgroundColor: Colors.green,
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
              content: Text('✅ Тестовая страница отправлена на печать'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Ошибка печати'),
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
            content: Text('Ошибка печати: $e'),
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
          // Кнопка обновления списка принтеров
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadPrinters,
            tooltip: 'Обновить список',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Карточка текущего статуса
                  _buildStatusCard(),
                  
                  const SizedBox(height: 24),
                  
                  // Список доступных принтеров
                  _buildPrintersList(),
                  
                  const SizedBox(height: 24),
                  
                  // Кнопка тестовой печати
                  if (_printer.isConnected) _buildTestPrintButton(),
                ],
              ),
            ),
    );
  }

  /// Карточка статуса принтера
  Widget _buildStatusCard() {
    final isConnected = _printerStatus['isConnected'] == true;
    final printerName = _printerStatus['printerName'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.print : Icons.print_disabled,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Статус принтера',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected ? 'Подключен' : 'Не подключен',
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Кнопка отвязать (только если подключен)
                if (isConnected)
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    color: Colors.red,
                    onPressed: _isRefreshing ? null : _unbindPrinter,
                    tooltip: 'Отвязать принтер',
                  ),
              ],
            ),
            
            // Информация о подключенном принтере
            if (isConnected && printerName != null) ...[
              const Divider(height: 24),
              _buildInfoRow('Название', printerName),
              if (_printerStatus['printerUrl'] != null)
                _buildInfoRow('URL', _printerStatus['printerUrl']),
              _buildInfoRow('Размер этикетки', '100 x 70 мм'),
              _buildInfoRow('Кириллица', 'Поддерживается'),
            ],
          ],
        ),
      ),
    );
  }

  /// Строка информации
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Список доступных принтеров
  Widget _buildPrintersList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Доступные принтеры',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        if (_availablePrinters.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Принтеры не найдены.\nПодключите принтер и нажмите "Обновить".',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_availablePrinters.length, (index) {
            final printer = _availablePrinters[index];
            final isCurrentPrinter = printer['name'] == _printerStatus['printerName'];
            
            return Card(
              color: isCurrentPrinter ? Colors.green.shade50 : null,
              elevation: isCurrentPrinter ? 4 : 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  isCurrentPrinter ? Icons.check_circle : Icons.print,
                  color: isCurrentPrinter ? Colors.green : AppTheme.primaryColor,
                ),
                title: Text(
                  printer['name'] ?? 'Неизвестный принтер',
                  style: TextStyle(
                    fontWeight: isCurrentPrinter ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  isCurrentPrinter ? 'Текущий принтер' : printer['url'] ?? '',
                  style: TextStyle(
                    color: isCurrentPrinter ? Colors.green : Colors.grey,
                    fontSize: 12,
                  ),
                ),
                trailing: isCurrentPrinter
                    ? const Icon(Icons.check, color: Colors.green)
                    : ElevatedButton(
                        onPressed: _isRefreshing ? null : () => _connectToPrinter(printer),
                        child: const Text('Подключить'),
                      ),
              ),
            );
          }),
      ],
    );
  }

  /// Кнопка тестовой печати
  Widget _buildTestPrintButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isRefreshing ? null : _printTestPage,
        icon: _isRefreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.print),
        label: Text(_isRefreshing ? 'Печать...' : 'Печать тестовой страницы'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
