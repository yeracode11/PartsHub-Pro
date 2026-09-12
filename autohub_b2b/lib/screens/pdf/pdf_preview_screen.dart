import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/generated_pdf_document.dart';
import 'package:autohub_b2b/services/pdf/pdf_file_export_service.dart';
import 'package:autohub_b2b/services/pdf/system_pdf_print_service.dart';
import 'package:autohub_b2b/services/api/api_user_message.dart';

/// Предпросмотр PDF с действиями: печать (системный диалог), сохранение в файл, пересборка.
///
/// Использует тот же [PdfPageFormat], что и генерация — без подмены на A4 в диалоге печати.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.generate,
    required this.suggestedFileName,
    this.shareSubject,
    this.appBarActions,
  });

  final String title;
  final Future<GeneratedPdfDocument> Function() generate;
  final String suggestedFileName;
  final String? shareSubject;
  final List<Widget>? appBarActions;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late Future<GeneratedPdfDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.generate();
  }

  void _regenerate() {
    setState(() {
      _future = widget.generate();
    });
  }

  bool get _showShare =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  bool get _showSaveToFile => !kIsWeb;

  Future<void> _print() async {
    try {
      final doc = await _future;
      if (!mounted) return;
      final ok = await SystemPdfPrintService.printGenerated(
        doc,
        jobName: widget.suggestedFileName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Отправлено на печать' : 'Печать отменена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Не удалось открыть печать'))),
      );
    }
  }

  Future<void> _save() async {
    try {
      final doc = await _future;
      if (!mounted) return;
      final path = await PdfFileExportService.savePdf(
        bytes: doc.bytes,
        suggestedName: widget.suggestedFileName,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: $path')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка сохранения'))),
      );
    }
  }

  Future<void> _share() async {
    try {
      final doc = await _future;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.suggestedFileName}');
      await file.writeAsBytes(doc.bytes, flush: true);

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'application/pdf',
              name: widget.suggestedFileName,
            ),
          ],
          subject: widget.shareSubject,
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingApiMessage(e, prefix: 'Ошибка отправки'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ...?widget.appBarActions,
          IconButton(
            tooltip: 'Обновить PDF',
            onPressed: _regenerate,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<GeneratedPdfDocument>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        userFacingApiMessage(
                          snapshot.error ?? 'Не удалось загрузить PDF',
                          prefix: 'Ошибка',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doc = snapshot.data!;
                return PdfPreview(
                  build: (PdfPageFormat format) async => doc.bytes,
                  initialPageFormat: doc.pageFormat,
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  useActions: false,
                  dynamicLayout: false,
                  maxPageWidth: w > 32 ? w - 32 : w,
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _print,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Печать'),
                    ),
                  ),
                  if (_showSaveToFile) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Сохранить'),
                      ),
                    ),
                  ],
                  if (_showShare) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Поделиться'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
