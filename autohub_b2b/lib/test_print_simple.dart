import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// МИНИМАЛЬНЫЙ ТЕСТ ПЕЧАТИ
/// Запустите этот экран чтобы проверить, работает ли printing вообще
class TestPrintSimple extends StatelessWidget {
  const TestPrintSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тест печати (минимальный)')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Нажмите кнопку для теста печати',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            
            // Тест 1A: Простейший PDF через layoutPdf (диалог)
            ElevatedButton(
              onPressed: () async {
                print('🧪 ТЕСТ 1A: layoutPdf (диалог печати)');
                try {
                  await Printing.layoutPdf(
                    onLayout: (PdfPageFormat format) async {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          build: (pw.Context context) {
                            return pw.Center(
                              child: pw.Text('TEST', style: const pw.TextStyle(fontSize: 48)),
                            );
                          },
                        ),
                      );
                      return pdf.save();
                    },
                  );
                  print('✅ ТЕСТ 1A: Успешно');
                } catch (e) {
                  print('❌ ТЕСТ 1A: Ошибка - $e');
                }
              },
              child: const Text('ТЕСТ 1A: layoutPdf'),
            ),
            
            const SizedBox(height: 10),
            
            // Тест 1B: Простейший PDF через sharePdf (сохранение)
            ElevatedButton(
              onPressed: () async {
                print('🧪 ТЕСТ 1B: sharePdf (сохранение/печать)');
                try {
                  final pdf = pw.Document();
                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) {
                        return pw.Center(
                          child: pw.Text('TEST SHARE', style: const pw.TextStyle(fontSize: 48)),
                        );
                      },
                    ),
                  );
                  final bytes = await pdf.save();
                  print('📄 PDF сгенерирован: ${bytes.length} байт');
                  
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'test.pdf',
                  );
                  print('✅ ТЕСТ 1B: Успешно (PDF сохранен/открыт)');
                } catch (e) {
                  print('❌ ТЕСТ 1B: Ошибка - $e');
                }
              },
              child: const Text('ТЕСТ 1B: sharePdf'),
            ),
            
            const SizedBox(height: 20),
            
            // Тест 2A: PDF стандартного размера (A4)
            ElevatedButton(
              onPressed: () async {
                print('🧪 ТЕСТ 2A: PDF стандартный размер (A4)');
                try {
                  final pdf = pw.Document();
                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) {
                        return pw.Center(
                          child: pw.Column(
                            mainAxisAlignment: pw.MainAxisAlignment.center,
                            children: [
                              pw.Text('TEST A4', style: const pw.TextStyle(fontSize: 32)),
                              pw.SizedBox(height: 16),
                              pw.Text('Standard size test', style: const pw.TextStyle(fontSize: 14)),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                  
                  final bytes = await pdf.save();
                  print('📄 PDF A4 сгенерирован: ${bytes.length} байт');
                  
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'test_a4.pdf',
                  );
                  print('✅ ТЕСТ 2A: Успешно');
                } catch (e) {
                  print('❌ ТЕСТ 2A: Ошибка - $e');
                }
              },
              child: const Text('ТЕСТ 2A: PDF A4'),
            ),
            
            const SizedBox(height: 10),
            
            // Тест 2B: Правильная этикетка для Xprinter XP-420B
            ElevatedButton(
              onPressed: () async {
                print('🧪 ТЕСТ 2B: Этикетка Xprinter 100x70мм');
                try {
                  final pdf = pw.Document();
                  
                  // Правильные параметры для термопринтера
                  // Для landscape (горизонтальной) ориентации: ширина > высоты
                  const mmToPoint = 2.83465;
                  final labelWidth = 100.0 * mmToPoint;   // 100mm ширина
                  final labelHeight = 70.0 * mmToPoint;   // 70mm высота
                  const margin = 2.0 * mmToPoint;         // 2mm отступы
                  
                  // Загружаем шрифт с поддержкой кириллицы
                  pw.Font? font;
                  try {
                    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
                    font = pw.Font.ttf(fontData);
                    print('✅ Шрифт Roboto загружен');
                  } catch (e) {
                    print('⚠️ Не удалось загрузить шрифт: $e');
                    font = null;
                  }
                  
                  pdf.addPage(
                    pw.Page(
                      pageFormat: PdfPageFormat(
                        labelWidth,
                        labelHeight,
                        marginAll: margin,
                      ),
                      build: (pw.Context context) {
                        return pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            // QR код слева
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'TEST-XP420B',
                              width: 50,
                              height: 50,
                            ),
                            pw.SizedBox(width: 8),
                            // Текст справа
                            pw.Expanded(
                              child: pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'ТЕСТОВАЯ ЭТИКЕТКА',
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                      font: font,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'Xprinter XP-420B',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      font: font,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    '100mm × 70mm',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      font: font,
                                    ),
                                  ),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'Цена: 15,990 ₸',
                                    style: pw.TextStyle(
                                      fontSize: 16,
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
                  
                  print('📄 Генерация этикетки 100x70мм...');
                  final bytes = await pdf.save();
                  print('✅ PDF сгенерирован: ${bytes.length} байт');
                  print('   Размер: ${labelWidth.toStringAsFixed(1)} × ${labelHeight.toStringAsFixed(1)} points');
                  
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'xprinter_label_100x70.pdf',
                  );
                  print('✅ ТЕСТ 2B: Откройте в Preview → ⌘P → Xprinter');
                } catch (e) {
                  print('❌ ТЕСТ 2B: Ошибка - $e');
                }
              },
              child: const Text('ТЕСТ 2B: Этикетка Xprinter 100×70мм'),
            ),
            
            const SizedBox(height: 20),
            
            // Тест 3: Список принтеров
            ElevatedButton(
              onPressed: () async {
                print('🧪 ТЕСТ 3: Получение списка принтеров');
                try {
                  final printers = await Printing.listPrinters();
                  print('✅ ТЕСТ 3: Найдено принтеров: ${printers.length}');
                  for (var printer in printers) {
                    print('  - ${printer.name} (${printer.url})');
                  }
                } catch (e) {
                  print('❌ ТЕСТ 3: Ошибка - $e');
                }
              },
              child: const Text('ТЕСТ 3: Список принтеров'),
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Смотрите логи в консоли',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

