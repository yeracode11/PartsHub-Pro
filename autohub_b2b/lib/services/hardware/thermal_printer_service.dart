import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'dart:async';
// Bluetooth printer support only for Android
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:permission_handler/permission_handler.dart';

void print(Object? object) {}

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
  String? _printerUrl; // URL принтера для сохранения
  pw.Font? _cyrillicFont;
  
  // Для Bluetooth на мобильных устройствах
  BlueThermalPrinter? _bluetoothPrinter;
  BluetoothDevice? _bluetoothDevice;
  
  // Ключи для SharedPreferences
  static const String _prefKeyPrinterName = 'saved_printer_name';
  static const String _prefKeyPrinterUrl = 'saved_printer_url';

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
        _printerUrl = _selectedPrinter!.url;
        
        // Сохраняем настройки принтера
        await savePrinterSettings();
        
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
  /// [clearSettings] - если true, также очищает сохраненные настройки (отвязать)
  Future<void> disconnect({bool clearSettings = false}) async {
    _isConnected = false;
    _printerName = null;
    _printerUrl = null;
    _selectedPrinter = null;
    
    if (clearSettings) {
      await clearPrinterSettings();
      print('🗑️ Принтер отвязан и настройки очищены');
    }
    
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

  /// Проверка подключения и геттеры
  bool get isConnected => _isConnected;
  String? get printerName => _printerName;
  String? get connectedPrinterName => _printerName; // Алиас для удобства

  /// Загрузка шрифта с поддержкой кириллицы
  /// 
  /// ВАЖНО: Библиотека pdf не поддерживает кириллицу по умолчанию.
  /// Для Windows библиотека printing использует системные шрифты при печати,
  /// но при генерации PDF нужен шрифт с поддержкой Unicode.
  /// 
  /// РЕШЕНИЕ: Используем встроенные шрифты из пакета pdf или системные шрифты.
  /// Загружает кириллический шрифт для печати на Windows
  /// Шрифт Roboto с поддержкой кириллицы включён в assets
  Future<pw.Font?> _loadCyrillicFont() async {
    // Кэшируем шрифт, чтобы не загружать каждый раз
    if (_cyrillicFont != null) {
      return _cyrillicFont;
    }
    
    try {
      print('📝 Загрузка кириллического шрифта Roboto...');
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      _cyrillicFont = pw.Font.ttf(fontData);
      print('✅ Кириллический шрифт Roboto загружен успешно');
      return _cyrillicFont;
    } catch (e) {
      print('⚠️ Не удалось загрузить шрифт из assets: $e');
      print('   На Windows будет использован системный шрифт');
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
    bool useDialog = false, // Новый параметр для использования диалога
  }) async {
    print('🖨️ Начало печати этикетки...');
    print('   Товар: $itemName');
    print('   Метод: ${useDialog ? "диалог" : "прямая печать"}');
    
    // Даём UI время на обновление перед тяжёлой операцией
    await Future.delayed(Duration.zero);
    
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
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // QR код слева (если есть артикул)
                  if (sku != null && sku.isNotEmpty) ...[
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: sku,
                      width: 55,
                      height: 55,
                    ),
                    pw.SizedBox(width: 6),
                  ],
                  
                  // Текстовая информация справа
                  pw.Expanded(
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Название товара
                        pw.Text(
                          itemName,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            font: font,
                          ),
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                        
                        pw.SizedBox(height: 3),
                        
                        // Артикул
                        if (sku != null && sku.isNotEmpty) ...[
                          pw.Text(
                            'Артикул: $sku',
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: font,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                        ],
                        
                        // Ячейка хранения
                        if (warehouseCell != null && warehouseCell.isNotEmpty) ...[
                          pw.Text(
                            'Ячейка: $warehouseCell',
                            style: pw.TextStyle(
                              fontSize: 12,
                              font: font,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                        ],
                        
                        // Цена (крупным шрифтом)
                        pw.Text(
                          '${price.toStringAsFixed(2)} ₸',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            font: font,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }

      // На macOS используем sharePdf для открытия в Preview
      // Это предотвращает зависание UI
      print('🖨️ Отправка на печать...');
      
      if (Platform.isMacOS) {
        print('📋 Открытие PDF в Preview (macOS)');
        print('   Используйте ⌘P для печати из Preview');
        
        // Генерируем PDF и открываем через Preview
        final pdfBytes = await pdf.save();
        print('✅ PDF сгенерирован (${pdfBytes.length} байт)');
        
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'label_${itemName.replaceAll(' ', '_')}.pdf',
        );
        
        print('✅ PDF открыт в Preview');
      } else {
        // Для Windows/Linux - сохраняем PDF и печатаем
        print('📄 Генерация PDF...');
        final pdfBytes = await pdf.save();
        print('✅ PDF сгенерирован (${pdfBytes.length} байт)');
        
        if (_selectedPrinter != null && !useDialog) {
          print('🎯 Прямая печать на $_printerName');
          await Printing.directPrintPdf(
            printer: _selectedPrinter!,
            onLayout: (PdfPageFormat format) async => pdfBytes,
          );
        } else {
          await Printing.layoutPdf(
            name: 'Этикетка: $itemName',
            onLayout: (PdfPageFormat format) async => pdfBytes,
          );
        }
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
    print('🖨️ Начало тестовой печати...');
    
    // Даём UI время на обновление перед тяжёлой операцией
    await Future.delayed(Duration.zero);
    
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
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // QR код слева
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'XPRINTER-TEST-${DateTime.now().millisecondsSinceEpoch}',
                  width: 55,
                  height: 55,
                ),
                pw.SizedBox(width: 6),
                
                // Текст справа
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ТЕСТ ПРИНТЕРА',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          font: font,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Размер: ${paperWidthMm.toInt()}×${paperHeightMm.toInt()} мм',
                        style: pw.TextStyle(
                          fontSize: 14,
                          font: font,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Кириллица: Работает',
                        style: pw.TextStyle(
                          fontSize: 12,
                          font: font,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        _printerName ?? "Системный принтер",
                        style: pw.TextStyle(
                          fontSize: 11,
                          font: font,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Простой подход для macOS
      print('🖨️ Отправка тестовой страницы...');
      
      if (Platform.isMacOS) {
        // На macOS используем sharePdf - открывает в Preview
        print('📋 Открытие PDF в Preview (macOS)...');
        print('   Используйте ⌘P для печати из Preview');
        
        final pdfBytes = await pdf.save();
        print('📄 PDF сгенерирован: ${pdfBytes.length} байт');
        
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'test_printer_${paperWidthMm.toInt()}x${paperHeightMm.toInt()}mm.pdf',
        );
        
        print('✅ PDF открыт в Preview');
      } else {
        // Для Windows/Linux
        print('📄 Генерация PDF...');
        final pdfBytes = await pdf.save();
        print('✅ PDF готов (${pdfBytes.length} байт)');
        
        if (_selectedPrinter != null) {
          await Printing.directPrintPdf(
            printer: _selectedPrinter!,
            onLayout: (PdfPageFormat format) async => pdfBytes,
          );
        } else {
          await Printing.layoutPdf(
            name: 'Тест принтера',
            onLayout: (PdfPageFormat format) async => pdfBytes,
          );
        }
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

  /// Сохранение настроек принтера
  Future<void> savePrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_printerName != null) {
        await prefs.setString(_prefKeyPrinterName, _printerName!);
        print('💾 Настройки принтера сохранены: $_printerName');
      }
      if (_printerUrl != null) {
        await prefs.setString(_prefKeyPrinterUrl, _printerUrl!);
      }
    } catch (e) {
      print('❌ Ошибка сохранения настроек принтера: $e');
    }
  }

  /// Загрузка сохраненных настроек принтера
  Future<Map<String, String?>> loadPrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_prefKeyPrinterName);
      final url = prefs.getString(_prefKeyPrinterUrl);
      
      if (name != null) {
        print('📥 Загружены настройки принтера: $name');
      }
      
      return {
        'name': name,
        'url': url,
      };
    } catch (e) {
      print('❌ Ошибка загрузки настроек принтера: $e');
      return {'name': null, 'url': null};
    }
  }

  /// Очистка сохраненных настроек принтера (отвязать)
  Future<void> clearPrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyPrinterName);
      await prefs.remove(_prefKeyPrinterUrl);
      print('🗑️ Настройки принтера очищены');
    } catch (e) {
      print('❌ Ошибка очистки настроек принтера: $e');
    }
  }

  /// Автоматическое подключение к сохраненному принтеру
  Future<bool> autoConnectToSavedPrinter() async {
    try {
      final settings = await loadPrinterSettings();
      final savedName = settings['name'];
      
      if (savedName == null) {
        print('ℹ️ Нет сохраненного принтера для автоподключения');
        return false;
      }

      print('🔄 Попытка автоподключения к сохраненному принтеру: $savedName');
      
      // Получаем список доступных принтеров
      final printers = await Printing.listPrinters();
      final savedPrinter = printers.where((p) => p.name == savedName).firstOrNull;
      
      if (savedPrinter != null) {
        _selectedPrinter = savedPrinter;
        _printerName = savedPrinter.name;
        _isConnected = true;
        print('✅ Автоматически подключено к: $_printerName');
        return true;
      } else {
        print('⚠️ Сохраненный принтер "$savedName" не найден');
        return false;
      }
    } catch (e) {
      print('❌ Ошибка автоподключения: $e');
      return false;
    }
  }

  /// Получение информации о текущем состоянии принтера
  Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'printerName': _printerName,
      'printerUrl': _printerUrl,
      'isBluetooth': _bluetoothPrinter != null,
      'bluetoothDevice': _bluetoothDevice?.name,
    };
  }

  /// Геттеры для расширенной информации
  String? get connectedPrinterUrl => _printerUrl;
}
