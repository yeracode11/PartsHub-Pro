import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Сервис для работы с термопринтером
/// 
/// Использует библиотеку `printing` для реальной печати на Windows
class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  Printer? _selectedPrinter;
  bool _isConnected = false;
  String? _printerName;

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

      // Размер наклейки: 58mm x 40mm (стандартный размер для термопринтеров)
      const labelWidth = 58.0 * PdfPoint.mm;
      const labelHeight = 40.0 * PdfPoint.mm;

      for (int i = 0; i < quantity; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(labelWidth, labelHeight, marginAll: 2 * PdfPoint.mm),
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
                    ),
                    textAlign: pw.TextAlign.center,
                    maxLines: 2,
                    overflow: pw.TextOverflow.ellipsis,
                  ),
                  pw.SizedBox(height: 4),
                  
                  // Артикул
                  if (sku != null && sku.isNotEmpty) ...[
                    pw.Text(
                      'Артикул: $sku',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 4),
                    
                    // Штрих-код
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: sku,
                      width: labelWidth - 8 * PdfPoint.mm,
                      height: 30,
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  
                  // Ячейка хранения
                  if (warehouseCell != null && warehouseCell.isNotEmpty) ...[
                    pw.Text(
                      'Ячейка: $warehouseCell',
                      style: const pw.TextStyle(fontSize: 10),
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

      const labelWidth = 58.0 * PdfPoint.mm;
      const labelHeight = 40.0 * PdfPoint.mm;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(labelWidth, labelHeight, marginAll: 2 * PdfPoint.mm),
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
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Если вы видите этот текст,',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'принтер работает корректно.',
                  style: const pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: 'TEST123456',
                  width: labelWidth - 8 * PdfPoint.mm,
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
  Future<List<Map<String, dynamic>>> getAvailableUSBPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      
      return printers.map((printer) {
        return {
          'name': printer.name,
          'url': printer.url,
          'model': printer.model,
          'location': printer.location,
          'comment': printer.comment,
        };
      }).toList();
    } catch (e) {
      print('❌ Ошибка получения списка принтеров: $e');
      return [];
    }
  }
}
