import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform, Socket, InternetAddress;
import 'dart:async';
import 'dart:convert';
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
  String? _printerUrl;
  pw.Font? _cyrillicFont;

  // WiFi TCP (все платформы, включая iOS)
  String? _wifiIp;
  int _wifiPort = 9100;
  bool _isWifi = false;
  
  // Ключи для SharedPreferences
  static const String _prefKeyPrinterName = 'saved_printer_name';
  static const String _prefKeyPrinterUrl = 'saved_printer_url';
  static const String _prefKeyPrinterType = 'saved_printer_type';
  static const String _prefKeyPrinterIp = 'saved_printer_ip';
  static const String _prefKeyPrinterPort = 'saved_printer_port';

  /// Подключение к принтеру
  /// 
  /// Если [printerName] не указан, будет показан диалог выбора принтера
  /// [printerData] — зарезервировано под расширения (например метаданные системного принтера).
  Future<bool> connectUSB({String? printerName, Map<String, dynamic>? printerData}) async {
    try {
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

      // Мобильные: системный список принтеров недоступен как на desktop; этикетки — PDF или WiFi TCP.
      print('⚠️ На мобильных: этикетка PDF из карточки товара или Wi‑Fi‑принтер (раздел ниже)');
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
    _wifiIp = null;
    _isWifi = false;
    
    if (clearSettings) {
      await clearPrinterSettings();
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
      // WiFi TCP (TSPL) — работает на iOS, Android, Desktop
      if (_isWifi && _wifiIp != null) {
        return await _printLabelWifi(
          itemName: itemName,
          sku: sku,
          price: price,
          warehouseCell: warehouseCell,
          quantity: quantity,
        );
      }

      // Системные принтеры (Desktop) и мобильные через PDF / layoutPdf — ниже
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

  /// Печать тестовой страницы
  Future<bool> printTestPage() async {
    print('🖨️ Начало тестовой печати...');
    
    // Даём UI время на обновление перед тяжёлой операцией
    await Future.delayed(Duration.zero);
    
    try {
      // WiFi TCP (TSPL)
      if (_isWifi && _wifiIp != null) {
        return await _printTestPageWifi();
      }

      // Системные принтеры (Desktop) — PDF
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

  // ===================== WiFi TCP (работает на iOS, Android, Desktop) =====================

  /// Подключение к принтеру по WiFi (TCP порт 9100). На iOS не используется (PDF / AirPrint).
  Future<bool> connectWifi(String ip, {int port = 9100}) async {
    if (Platform.isIOS) return false;
    try {
      // Проверяем доступность принтера
      final socket = await Socket.connect(
        InternetAddress(ip),
        port,
        timeout: const Duration(seconds: 5),
      );
      await socket.close();

      // Отключаемся от предыдущего
      if (_isConnected) await disconnect();

      _wifiIp = ip;
      _wifiPort = port;
      _isWifi = true;
      _isConnected = true;
      _printerName = 'WiFi: $ip:$port';
      _printerUrl = 'tcp://$ip:$port';

      await savePrinterSettings();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Отправка raw-байт на WiFi-принтер через TCP-сокет
  Future<bool> _sendToWifi(List<int> data) async {
    if (_wifiIp == null) return false;
    try {
      final socket = await Socket.connect(
        InternetAddress(_wifiIp!),
        _wifiPort,
        timeout: const Duration(seconds: 5),
      );
      socket.add(data);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Печать наклейки на WiFi-принтере с помощью TSPL (язык Xprinter XP-420B).
  /// Поддерживает кириллицу, QR-код, штрих-код.
  Future<bool> _printLabelWifi({
    required String itemName,
    required String? sku,
    required double price,
    String? warehouseCell,
    int quantity = 1,
  }) async {
    final buf = StringBuffer();

    for (int i = 0; i < quantity; i++) {
      buf.writeln('SIZE $paperWidthMm mm, $paperHeightMm mm');
      buf.writeln('GAP 2 mm, 0 mm');
      buf.writeln('DIRECTION 1,0');
      buf.writeln('CLS');
      buf.writeln('CODEPAGE UTF-8');

      int y = 24;
      const leftText = 200;

      // QR-код слева
      if (sku != null && sku.isNotEmpty) {
        buf.writeln('QRCODE 24,$y,L,6,A,0,"$sku"');
      }

      // Название товара (крупный шрифт)
      final safeName = itemName.replaceAll('"', "'");
      buf.writeln('TEXT $leftText,$y,"4",0,1,1,"$safeName"');
      y += 60;

      // Артикул
      if (sku != null && sku.isNotEmpty) {
        buf.writeln('TEXT $leftText,$y,"3",0,1,1,"Art: $sku"');
        y += 40;
      }

      // Ячейка хранения
      if (warehouseCell != null && warehouseCell.isNotEmpty) {
        final safeCell = warehouseCell.replaceAll('"', "'");
        buf.writeln('TEXT $leftText,$y,"3",0,1,1,"Cell: $safeCell"');
        y += 40;
      }

      // Цена (крупный)
      buf.writeln('TEXT $leftText,$y,"4",0,1,1,"${price.toStringAsFixed(0)} T"');

      buf.writeln('PRINT 1,1');
    }

    return await _sendToWifi(utf8.encode(buf.toString()));
  }

  /// Тестовая печать на WiFi-принтере
  Future<bool> _printTestPageWifi() async {
    final buf = StringBuffer();
    buf.writeln('SIZE $paperWidthMm mm, $paperHeightMm mm');
    buf.writeln('GAP 2 mm, 0 mm');
    buf.writeln('DIRECTION 1,0');
    buf.writeln('CLS');
    buf.writeln('CODEPAGE UTF-8');
    buf.writeln('TEXT 24,24,"4",0,1,1,"TEST PRINTER"');
    buf.writeln('TEXT 24,100,"3",0,1,1,"WiFi: $_wifiIp:$_wifiPort"');
    buf.writeln('TEXT 24,160,"3",0,1,1,"${paperWidthMm.toInt()}x${paperHeightMm.toInt()} mm"');
    buf.writeln('QRCODE 24,230,L,6,A,0,"AUTOHUB-TEST"');
    buf.writeln('TEXT 200,260,"3",0,1,1,"AutoHub B2B"');
    buf.writeln('PRINT 1,1');
    return await _sendToWifi(utf8.encode(buf.toString()));
  }

  bool get isWifi => _isWifi;
  String? get wifiIp => _wifiIp;
  int get wifiPort => _wifiPort;

  /// Список системных принтеров (desktop / AirPrint на iOS).
  Future<List<Map<String, dynamic>>> getAvailableUSBPrinters() async {
    try {
      final List<Map<String, dynamic>> allPrinters = [];

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
            final url = printer.url.toLowerCase();
            if (url.contains('bluetooth') || url.contains('bt')) {
              connectionType = 'Bluetooth';
            } else if (url.contains('usb')) {
              connectionType = 'USB';
            } else if (url.contains('http') || url.contains('ipp') || url.contains('socket')) {
              connectionType = 'Сетевой';
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
      }
      if (_printerUrl != null) {
        await prefs.setString(_prefKeyPrinterUrl, _printerUrl!);
      }
      if (_isWifi && _wifiIp != null) {
        await prefs.setString(_prefKeyPrinterType, 'wifi');
        await prefs.setString(_prefKeyPrinterIp, _wifiIp!);
        await prefs.setInt(_prefKeyPrinterPort, _wifiPort);
      } else {
        await prefs.setString(_prefKeyPrinterType, 'system');
      }
    } catch (_) {}
  }

  /// Загрузка сохраненных настроек принтера
  Future<Map<String, String?>> loadPrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'name': prefs.getString(_prefKeyPrinterName),
        'url': prefs.getString(_prefKeyPrinterUrl),
        'type': prefs.getString(_prefKeyPrinterType),
        'ip': prefs.getString(_prefKeyPrinterIp),
        'port': prefs.getInt(_prefKeyPrinterPort)?.toString(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Очистка сохраненных настроек принтера (отвязать)
  Future<void> clearPrinterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyPrinterName);
      await prefs.remove(_prefKeyPrinterUrl);
      await prefs.remove(_prefKeyPrinterType);
      await prefs.remove(_prefKeyPrinterIp);
      await prefs.remove(_prefKeyPrinterPort);
    } catch (_) {}
  }

  /// Автоматическое подключение к сохраненному принтеру
  Future<bool> autoConnectToSavedPrinter() async {
    try {
      // На iOS печать — через PDF / системный диалог; прямой TCP к принтеру не используем.
      if (Platform.isIOS) return false;

      final settings = await loadPrinterSettings();
      final savedType = settings['type'];
      final savedName = settings['name'];

      if (savedName == null) return false;

      // Раньше сохраняли type bluetooth — больше не поддерживается
      if (savedType == 'bluetooth') {
        return false;
      }

      // WiFi auto-reconnect
      if (savedType == 'wifi') {
        final ip = settings['ip'];
        final port = int.tryParse(settings['port'] ?? '') ?? 9100;
        if (ip != null) {
          return await connectWifi(ip, port: port);
        }
        return false;
      }

      // System printer auto-reconnect (Desktop)
      if (savedType == 'system' || savedType == null) {
        try {
          final printers = await Printing.listPrinters();
          final savedPrinter = printers.where((p) => p.name == savedName).firstOrNull;
          if (savedPrinter != null) {
            _selectedPrinter = savedPrinter;
            _printerName = savedPrinter.name;
            _isConnected = true;
            return true;
          }
        } catch (_) {}
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Получение информации о текущем состоянии принтера
  Map<String, dynamic> getPrinterStatus() {
    return {
      'isConnected': _isConnected,
      'printerName': _printerName,
      'printerUrl': _printerUrl,
      'isWifi': _isWifi,
      'wifiIp': _wifiIp,
      'wifiPort': _wifiPort,
    };
  }

  /// Геттеры для расширенной информации
  String? get connectedPrinterUrl => _printerUrl;
}
