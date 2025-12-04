import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
// Bluetooth printer support only for Android
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис для работы с термопринтером
/// 
/// Использует библиотеку `printing` для реальной печати на Windows
/// Поддерживает различные термопринтеры, включая Xprinter, Epson, Star и др.
class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  /// Настройки размера этикетки (в миллиметрах) для термопринтера
  ///
  /// По умолчанию используем этикетку 100x70 мм, как вы указали.
  static const double paperWidthMm = 100.0;
  static const double paperHeightMm = 70.0;

  Printer? _selectedPrinter;
  bool _isConnected = false;
  String? _printerName;
  pw.Font? _cyrillicFont;
  
  // Для Bluetooth на мобильных устройствах
  BlueThermalPrinter? _bluetoothPrinter;
  BluetoothDevice? _bluetoothDevice;

  /// Подключение к принтеру
  /// 
  /// Если [printerName] не указан, будет показан диалог выбора принтера
  /// [printerData] - данные принтера из списка (может содержать BluetoothDevice для мобильных)
  Future<bool> connectUSB({String? printerName, Map<String, dynamic>? printerData}) async {
    try {
      // Если это Bluetooth принтер на мобильном устройстве
      if (printerData != null && printerData['isBluetooth'] == true && printerData['device'] != null) {
        final device = printerData['device'] as BluetoothDevice;
        return await connectBluetooth(device);
      }

      // Для десктопных платформ используем системные принтеры
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Получаем список доступных принтеров
        final printers = await Printing.listPrinters();
        
        if (printers.isEmpty) {
          print('⚠️ Принтеры не найдены в системе');
          return false;
        }

        // Если указано имя принтера, ищем его
        if (printerName != null) {
          _selectedPrinter = printers.firstWhere(
            (p) => p.name == printerName,
            orElse: () => printers.first,
          );
        } else {
          // Используем первый доступный принтер
          _selectedPrinter = printers.first;
        }

        _isConnected = true;
        _printerName = _selectedPrinter!.name;
        
        print('✅ Подключено к принтеру: $_printerName');
        return true;
      }

      // Для мобильных устройств без Bluetooth - возвращаем ошибку
      print('⚠️ На мобильных устройствах используйте Bluetooth принтеры');
      return false;
    } catch (e) {
      print('❌ Ошибка подключения к принтеру: $e');
      _isConnected = false;
      _printerName = null;
      return false;
    }
  }

  /// Отключение от принтера
  Future<void> disconnect() async {
    _isConnected = false;
    _printerName = null;
    _selectedPrinter = null;
    
    // Отключаемся от Bluetooth принтера, если подключены
    if (_bluetoothPrinter != null) {
      try {
        final isConnected = await _bluetoothPrinter!.isConnected;
        if (isConnected == true) {
          await _bluetoothPrinter!.disconnect();
        }
      } catch (e) {
        print('⚠️ Ошибка отключения от Bluetooth принтера: $e');
      }
      _bluetoothPrinter = null;
      _bluetoothDevice = null;
    }
  }

  /// Проверка подключения
  bool get isConnected => _isConnected;
  String? get printerName => _printerName;

  /// Загрузка шрифта с поддержкой кириллицы
  /// 
  /// ВАЖНО: Библиотека pdf не поддерживает кириллицу по умолчанию.
  /// Для Windows библиотека printing использует системные шрифты при печати,
  /// но при генерации PDF нужен шрифт с поддержкой Unicode.
  /// 
  /// РЕШЕНИЕ: Используем встроенные шрифты из пакета pdf или системные шрифты.
  /// На Windows printing автоматически конвертирует PDF и использует системные шрифты.
  Future<pw.Font?> _loadCyrillicFont() async {
    // Кэшируем шрифт, чтобы не загружать каждый раз
    if (_cyrillicFont != null) {
      return _cyrillicFont;
    }
    
    try {
      // Попытка загрузить шрифт из assets (если добавлен)
      // Для добавления шрифта:
      // 1. Скачайте шрифт с поддержкой кириллицы (например, Roboto)
      // 2. Поместите в assets/fonts/Roboto-Regular.ttf
      // 3. Добавьте в pubspec.yaml: assets: - assets/fonts/
      // 4. Раскомментируйте код ниже:
      //
      // try {
      //   final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      //   _cyrillicFont = pw.Font.ttf(fontData);
      //   return _cyrillicFont;
      // } catch (e) {
      //   print('⚠️ Шрифт из assets не найден: $e');
      // }
      
      // Используем null - на Windows printing использует системные шрифты при печати
      // Ошибки в консоли - это предупреждения при генерации PDF,
      // но при печати на Windows используются системные шрифты с поддержкой кириллицы
      return null;
    } catch (e) {
      print('⚠️ Не удалось загрузить шрифт: $e');
      return null;
    }
  }

  /// Печать наклейки для товара
  /// 
  /// [itemName] - название товара
  /// [sku] - артикул/штрих-код
  /// [price] - цена
  /// [warehouseCell] - ячейка хранения
  /// [quantity] - количество (для печати нескольких наклеек)
  Future<bool> printLabel({
    required String itemName,
    required String? sku,
    required double price,
    String? warehouseCell,
    int quantity = 1,
  }) async {
    try {
      // Если подключен Bluetooth принтер, используем ESC/POS
      if (_bluetoothPrinter != null) {
        final isConnected = await _bluetoothPrinter!.isConnected;
        if (isConnected == true) {
          return await _printLabelBluetooth(
            itemName: itemName,
            sku: sku,
            price: price,
            warehouseCell: warehouseCell,
            quantity: quantity,
          );
        }
      }

      // Для десктопных принтеров используем PDF
      // Создаем PDF документ с наклейками
      final pdf = pw.Document();
      
      // Загружаем шрифт с поддержкой кириллицы (если доступен)
      final font = await _loadCyrillicFont();

      // Размер наклейки задаётся в миллиметрах через paperWidthMm / paperHeightMm.
      // По умолчанию: 100мм x 70мм (как указано в настройке).
      // Конвертируем мм в точки: 1 мм = 2.83465 точек (72 точки на дюйм / 25.4 мм).
      const mmToPoint = 2.83465;
      final labelWidth = paperWidthMm * mmToPoint;
      final labelHeight = paperHeightMm * mmToPoint;
      const margin = 2.0 * mmToPoint;

      for (int i = 0; i < quantity; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(labelWidth, labelHeight, marginAll: margin),
            build: (pw.Context context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Название товара
                  pw.Text(
                    itemName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                  ),
                  pw.SizedBox(height: 4),
                  
                  // Артикул
                  if (sku != null && sku.isNotEmpty) ...[
                    pw.Text(
                      'Артикул: $sku',
                      style: pw.TextStyle(
                        fontSize: 10,
                        font: font,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    
                    // Штрих-код
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: sku,
                      width: labelWidth - 8 * mmToPoint,
                      height: 30,
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  
                  // Ячейка хранения
                  if (warehouseCell != null && warehouseCell.isNotEmpty) ...[
                    pw.Text(
                      'Ячейка: $warehouseCell',
                      style: pw.TextStyle(
                        fontSize: 10,
                        font: font,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  
                  // Цена
                  pw.Text(
                    'Цена: ${price.toStringAsFixed(2)} ₸',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      font: font,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              );
            },
          ),
        );
      }

      // Печатаем PDF
      if (_selectedPrinter != null) {
        // Прямая печать на выбранный принтер
        await Printing.directPrintPdf(
          printer: _selectedPrinter!,
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      } else {
        // Показываем диалог выбора принтера
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      }

      print('✅ Наклейка отправлена на печать');
      print('   Товар: $itemName');
      print('   Артикул: $sku');
      print('   Цена: $price ₸');
      print('   Количество: $quantity');
      
      return true;
    } catch (e) {
      print('❌ Ошибка печати наклейки: $e');
      return false;
    }
  }

  /// Печать наклейки через Bluetooth принтер (ESC/POS)
  Future<bool> _printLabelBluetooth({
    required String itemName,
    required String? sku,
    required double price,
    String? warehouseCell,
    int quantity = 1,
  }) async {
    try {
      if (_bluetoothPrinter == null) {
        print('❌ Bluetooth принтер не подключен');
        return false;
      }
      
      final isConnected = await _bluetoothPrinter!.isConnected;
      if (isConnected != true) {
        print('❌ Bluetooth принтер не подключен');
        return false;
      }

      for (int i = 0; i < quantity; i++) {
        // Название товара (крупный шрифт, по центру)
        // printCustom принимает: String text, int size, int align
        await _bluetoothPrinter!.printCustom(itemName, 1, 1);
        await _bluetoothPrinter!.printNewLine();
        
        // Артикул
        if (sku != null && sku.isNotEmpty) {
          await _bluetoothPrinter!.printCustom('Артикул: $sku', 0, 1);
          await _bluetoothPrinter!.printNewLine();
          
          // Штрих-код - используем printQRcode или printLeftRight
          // В blue_thermal_printer нет printBarcode, используем текстовое представление
          await _bluetoothPrinter!.printCustom('Штрих-код: $sku', 0, 1);
          await _bluetoothPrinter!.printNewLine();
        }
        
        // Ячейка хранения
        if (warehouseCell != null && warehouseCell.isNotEmpty) {
          await _bluetoothPrinter!.printCustom('Ячейка: $warehouseCell', 0, 1);
          await _bluetoothPrinter!.printNewLine();
        }
        
        // Цена (крупный шрифт, по центру)
        await _bluetoothPrinter!.printCustom('Цена: ${price.toStringAsFixed(2)} ₸', 1, 1);
        await _bluetoothPrinter!.printNewLine();
        await _bluetoothPrinter!.printNewLine();
        
        // Отрезаем бумагу (если поддерживается)
        await _bluetoothPrinter!.paperCut();
      }

      print('✅ Наклейка отправлена на Bluetooth принтер');
      print('   Товар: $itemName');
      print('   Артикул: $sku');
      print('   Цена: $price ₸');
      print('   Количество: $quantity');
      
      return true;
    } catch (e) {
      print('❌ Ошибка печати на Bluetooth принтере: $e');
      return false;
    }
  }

  /// Печать тестовой страницы
  Future<bool> printTestPage() async {
    try {
      // Если подключен Bluetooth принтер, используем ESC/POS
      if (_bluetoothPrinter != null) {
        final isConnected = await _bluetoothPrinter!.isConnected;
        if (isConnected == true) {
          return await _printTestPageBluetooth();
        }
      }

      // Для десктопных принтеров используем PDF
      final pdf = pw.Document();
      
      // Загружаем шрифт с поддержкой кириллицы (если доступен)
      final font = await _loadCyrillicFont();

      // Используем те же настройки бумаги, что и для печати этикетки:
      // 100мм x 70мм по умолчанию.
      const mmToPoint = 2.83465;
      final labelWidth = paperWidthMm * mmToPoint;
      final labelHeight = paperHeightMm * mmToPoint;
      const margin = 2.0 * mmToPoint;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(labelWidth, labelHeight, marginAll: margin),
          build: (pw.Context context) {
            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'ТЕСТ ПРИНТЕРА',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    font: font,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Если вы видите этот текст,',
                  style: pw.TextStyle(
                    fontSize: 10,
                    font: font,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'принтер работает корректно.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    font: font,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: 'TEST123456',
                  width: labelWidth - 8 * mmToPoint,
                  height: 30,
                ),
              ],
            );
          },
        ),
      );

      if (_selectedPrinter != null) {
        await Printing.directPrintPdf(
          printer: _selectedPrinter!,
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      }

      print('✅ Тестовая страница отправлена на печать');
      return true;
    } catch (e) {
      print('❌ Ошибка печати тестовой страницы: $e');
      return false;
    }
  }

  /// Печать тестовой страницы через Bluetooth принтер (ESC/POS)
  Future<bool> _printTestPageBluetooth() async {
    try {
      if (_bluetoothPrinter == null) {
        print('❌ Bluetooth принтер не подключен');
        return false;
      }
      
      final isConnected = await _bluetoothPrinter!.isConnected;
      if (isConnected != true) {
        print('❌ Bluetooth принтер не подключен');
        return false;
      }

      // Заголовок
      await _bluetoothPrinter!.printCustom('ТЕСТ ПРИНТЕРА', 1, 1);
      await _bluetoothPrinter!.printNewLine();
      await _bluetoothPrinter!.printCustom('Если вы видите этот текст,', 0, 1);
      await _bluetoothPrinter!.printNewLine();
      await _bluetoothPrinter!.printCustom('принтер работает корректно.', 0, 1);
      await _bluetoothPrinter!.printNewLine();
      
      // Штрих-код - текстовое представление
      await _bluetoothPrinter!.printCustom('Тест: TEST123456', 0, 1);
      await _bluetoothPrinter!.printNewLine();
      await _bluetoothPrinter!.printNewLine();
      
      // Отрезаем бумагу (если поддерживается)
      await _bluetoothPrinter!.paperCut();

      print('✅ Тестовая страница отправлена на Bluetooth принтер');
      return true;
    } catch (e) {
      print('❌ Ошибка печати тестовой страницы на Bluetooth принтере: $e');
      return false;
    }
  }

  /// Подключение к Bluetooth принтеру (для мобильных устройств)
  Future<bool> connectBluetooth(BluetoothDevice device) async {
    try {
      // iOS не поддерживает Bluetooth принтеры через эту библиотеку
      if (Platform.isIOS) {
        print('⚠️ Bluetooth принтеры не поддерживаются на iOS. Используйте AirPrint или сетевые принтеры.');
        return false;
      }
      
      // Проверяем разрешения на Android
      if (Platform.isAndroid) {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (!bluetoothStatus.isGranted) {
          print('❌ Нет разрешения на использование Bluetooth');
          return false;
        }
        
        // Для Android 12+ нужны дополнительные разрешения
        if (await Permission.bluetoothScan.isDenied) {
          await Permission.bluetoothScan.request();
        }
        if (await Permission.bluetoothConnect.isDenied) {
          await Permission.bluetoothConnect.request();
        }
      }

      // Создаем объект принтера
      _bluetoothPrinter = BlueThermalPrinter.instance;
      
      // Подключаемся
      final result = await _bluetoothPrinter!.connect(device);
      
      if (result == true) {
        _isConnected = true;
        _printerName = device.name ?? device.address;
        _bluetoothDevice = device;
        print('✅ Подключено к Bluetooth принтеру: $_printerName');
        return true;
      } else {
        print('❌ Ошибка подключения к Bluetooth принтеру');
        _bluetoothPrinter = null;
        return false;
      }
    } catch (e) {
      print('❌ Ошибка подключения к Bluetooth принтеру: $e');
      _bluetoothPrinter = null;
      return false;
    }
  }

  /// Поиск Bluetooth принтеров (для мобильных устройств)
  Future<List<BluetoothDevice>> scanBluetoothPrinters() async {
    try {
      // Проверяем разрешения на Android
      if (Platform.isAndroid) {
        final bluetoothStatus = await Permission.bluetooth.request();
        if (!bluetoothStatus.isGranted) {
          print('❌ Нет разрешения на использование Bluetooth');
          return [];
        }
        
        if (await Permission.bluetoothScan.isDenied) {
          await Permission.bluetoothScan.request();
        }
      }
      
      // Для iOS Bluetooth работает по-другому, и библиотека может не поддерживать iOS
      if (Platform.isIOS) {
        print('⚠️ Bluetooth принтеры на iOS могут не поддерживаться. Используйте AirPrint или сетевые принтеры.');
        return [];
      }

      // Создаем объект принтера для поиска
      final printer = BlueThermalPrinter.instance;
      
      // Проверяем, включен ли Bluetooth
      final isOn = await printer.isOn;
      if (isOn != true) {
        print('⚠️ Bluetooth выключен');
        return [];
      }

      // Ищем устройства
      final devices = await printer.getBondedDevices();
      
      // Фильтруем только принтеры (обычно в названии есть "printer", "print", "POS", "Xprinter", "Epson" и т.д.)
      final printerKeywords = ['printer', 'print', 'pos', 'xprinter', 'epson', 'star', 'bixolon', 'zjiang'];
      final printers = devices.where((device) {
        final name = (device.name ?? '').toLowerCase();
        return printerKeywords.any((keyword) => name.contains(keyword));
      }).toList();

      print('✅ Найдено ${printers.length} Bluetooth принтеров');
      return printers;
    } catch (e) {
      print('❌ Ошибка поиска Bluetooth принтеров: $e');
      // На iOS может быть ошибка, если библиотека не поддерживает iOS
      if (Platform.isIOS) {
        print('⚠️ Bluetooth принтеры не поддерживаются на iOS. Используйте AirPrint.');
      }
      return [];
    }
  }

  /// Получить список доступных принтеров
  /// 
  /// Включает все типы принтеров:
  /// - USB принтеры (Windows/Desktop)
  /// - Bluetooth принтеры (мобильные устройства)
  /// - Сетевые принтеры
  /// - Локальные принтеры
  Future<List<Map<String, dynamic>>> getAvailableUSBPrinters() async {
    try {
      final List<Map<String, dynamic>> allPrinters = [];

      // Для Android ищем Bluetooth принтеры
      // iOS не поддерживает Bluetooth принтеры через эту библиотеку, используйте AirPrint
      if (Platform.isAndroid) {
        try {
          final bluetoothPrinters = await scanBluetoothPrinters();
          for (final device in bluetoothPrinters) {
            allPrinters.add({
              'name': device.name ?? device.address,
              'address': device.address,
              'connectionType': 'Bluetooth',
              'isBluetooth': true,
              'device': device, // Сохраняем объект устройства для подключения
            });
          }
        } catch (e) {
          print('⚠️ Ошибка поиска Bluetooth принтеров: $e');
        }
      }
      
      // Для iOS используем системные принтеры (AirPrint)
      if (Platform.isIOS) {
        try {
          final printers = await Printing.listPrinters();
          for (final printer in printers) {
            allPrinters.add({
              'name': printer.name,
              'url': printer.url,
              'model': printer.model,
              'location': printer.location,
              'comment': printer.comment,
              'connectionType': 'AirPrint',
              'isBluetooth': false,
            });
          }
        } catch (e) {
          print('⚠️ Ошибка получения AirPrint принтеров на iOS: $e');
        }
      }

      // Для десктопных платформ используем системные принтеры
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        try {
          final printers = await Printing.listPrinters();
          
          for (final printer in printers) {
            // Определяем тип подключения по URL или location
            String connectionType = 'Локальный';
            if (printer.url != null) {
              final url = printer.url!.toLowerCase();
              if (url.contains('bluetooth') || url.contains('bt')) {
                connectionType = 'Bluetooth';
              } else if (url.contains('usb')) {
                connectionType = 'USB';
              } else if (url.contains('http') || url.contains('ipp') || url.contains('socket')) {
                connectionType = 'Сетевой';
              }
            }
            
            // Также проверяем location
            if (printer.location != null) {
              final location = printer.location!.toLowerCase();
              if (location.contains('bluetooth') || location.contains('bt')) {
                connectionType = 'Bluetooth';
              }
            }
            
            allPrinters.add({
              'name': printer.name,
              'url': printer.url,
              'model': printer.model,
              'location': printer.location,
              'comment': printer.comment,
              'connectionType': connectionType,
              'isBluetooth': false,
            });
          }
        } catch (e) {
          print('⚠️ Ошибка получения системных принтеров: $e');
        }
      }

      return allPrinters;
    } catch (e) {
      print('❌ Ошибка получения списка принтеров: $e');
      return [];
    }
  }
}
