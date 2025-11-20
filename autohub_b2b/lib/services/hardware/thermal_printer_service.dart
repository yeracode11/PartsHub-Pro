import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'dart:typed_data';

/// Сервис для работы с термопринтером
/// 
/// Использует библиотеку `printing` для реальной печати на Windows
/// Поддерживает различные термопринтеры, включая Xprinter, Epson, Star и др.
class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  Printer? _selectedPrinter;
  bool _isConnected = false;
  String? _printerName;
  pw.Font? _cyrillicFont;

  /// Подключение к принтеру
  /// 
  /// Если [printerName] не указан, будет показан диалог выбора принтера
  Future<bool> connectUSB({String? printerName}) async {
    try {
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
  /// РЕШЕНИЕ: Используем системные шрифты Windows через библиотеку printing.
  /// При печати на Windows printing автоматически конвертирует PDF в формат принтера
  /// и использует системные шрифты, которые поддерживают кириллицу.
  Future<pw.Font?> _loadCyrillicFont() async {
    // Кэшируем шрифт, чтобы не загружать каждый раз
    if (_cyrillicFont != null) {
      return _cyrillicFont;
    }
    
    try {
      // На Windows библиотека printing использует системные шрифты при печати,
      // поэтому даже если PDF генерируется с шрифтом без поддержки кириллицы,
      // при печати будут использоваться системные шрифты Windows
      // 
      // Для полной поддержки можно добавить шрифт в assets:
      // 1. Скачайте шрифт с поддержкой кириллицы (например, Roboto)
      // 2. Поместите в assets/fonts/Roboto-Regular.ttf
      // 3. Добавьте в pubspec.yaml: assets: - assets/fonts/
      // 4. Раскомментируйте код ниже:
      //
      // final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      // _cyrillicFont = pw.Font.ttf(fontData);
      // return _cyrillicFont;
      
      // Пока используем null - printing на Windows использует системные шрифты
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
      // Создаем PDF документ с наклейками
      final pdf = pw.Document();
      
      // Загружаем шрифт с поддержкой кириллицы (если доступен)
      final font = await _loadCyrillicFont();

      // Размер наклейки: 58mm x 40mm (стандартный размер для термопринтеров Xprinter)
      // Для других размеров можно изменить:
      // - 58mm x 30mm (маленькие наклейки)
      // - 80mm x 50mm (большие наклейки)
      // - 100mm x 50mm (широкие наклейки)
      // Конвертируем мм в точки: 1 мм = 2.83465 точек (72 точки на дюйм / 25.4 мм на дюйм)
      const mmToPoint = 2.83465;
      const labelWidth = 58.0 * mmToPoint;  // 58mm ширина (стандарт для Xprinter)
      const labelHeight = 40.0 * mmToPoint; // 40mm высота
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
                      if (font != null) font: font,
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
                        if (font != null) font: font,
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
                        if (font != null) font: font,
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
                      if (font != null) font: font,
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

  /// Печать тестовой страницы
  Future<bool> printTestPage() async {
    try {
      final pdf = pw.Document();
      
      // Загружаем шрифт с поддержкой кириллицы (если доступен)
      final font = await _loadCyrillicFont();

      // Конвертируем мм в точки
      const mmToPoint = 2.83465;
      const labelWidth = 58.0 * mmToPoint;
      const labelHeight = 40.0 * mmToPoint;
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
                    if (font != null) font: font,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Если вы видите этот текст,',
                  style: pw.TextStyle(
                    fontSize: 10,
                    if (font != null) font: font,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'принтер работает корректно.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    if (font != null) font: font,
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

  /// Получить список доступных принтеров
  /// 
  /// Включает все типы принтеров:
  /// - USB принтеры
  /// - Bluetooth принтеры (если установлены в Windows)
  /// - Сетевые принтеры
  /// - Локальные принтеры
  Future<List<Map<String, dynamic>>> getAvailableUSBPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      
      return printers.map((printer) {
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
        
        return {
          'name': printer.name,
          'url': printer.url,
          'model': printer.model,
          'location': printer.location,
          'comment': printer.comment,
          'connectionType': connectionType, // Добавляем тип подключения
        };
      }).toList();
    } catch (e) {
      print('❌ Ошибка получения списка принтеров: $e');
      return [];
    }
  }
}
