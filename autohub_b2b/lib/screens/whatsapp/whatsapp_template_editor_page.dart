import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';

/// Редактор одного шаблона WhatsApp (создание или изменение).
class WhatsAppTemplateEditorPage extends StatefulWidget {
  final Dio dio;
  final Map<String, dynamic>? existing;

  const WhatsAppTemplateEditorPage({
    super.key,
    required this.dio,
    this.existing,
  });

  bool get isEdit => existing != null;

  @override
  State<WhatsAppTemplateEditorPage> createState() =>
      _WhatsAppTemplateEditorPageState();
}

class _WhatsAppTemplateEditorPageState extends State<WhatsAppTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late String _category;
  bool _saving = false;

  static const Map<String, String> _categoryLabels = {
    'notification': 'Уведомления',
    'reminder': 'Напоминания',
    'promo': 'Акции и промо',
    'greeting': 'Поздравления',
    'custom': 'Свой вариант',
  };

  /// Переменные, которые подставляет сервер при рассылке (имена как у бэкенда).
  static const List<String> _variableKeys = [
    'name',
    'carModel',
    'organizationName',
    'orderNumber',
    'status',
    'itemName',
    'sku',
    'reserveUntil',
    'phone',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?['name']?.toString() ?? '');
    _contentController = TextEditingController(
      text: e?['content']?.toString() ?? '',
    );
    final raw = e?['category']?.toString().toLowerCase();
    _category = _categoryLabels.containsKey(raw) ? raw! : 'custom';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String key) {
    final token = '{$key}';
    final controller = _contentController;
    final sel = controller.selection;
    final text = controller.text;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : start;
    final newText = text.replaceRange(start, end, token);
    final newOffset = start + token.length;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  Future<void> _save() async {
    if (!await ensureAuthenticated(context)) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final content = _contentController.text.trim();
    final payload = <String, dynamic>{
      'name': name,
      'content': content,
      'category': _category,
    };

    try {
      if (widget.isEdit) {
        final id = widget.existing!['id'];
        await widget.dio.put('/api/whatsapp/templates/$id', data: payload);
      } else {
        await widget.dio.post('/api/whatsapp/templates', data: payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEdit ? 'Шаблон сохранён' : 'Шаблон создан'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response?.data['message']?.toString() ??
              e.response?.data['error']?.toString())
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg ?? e.message ?? 'Не удалось сохранить шаблон',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Редактирование шаблона' : 'Новый шаблон'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Например: Готов к выдаче',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите название';
                }
                if (v.trim().length > 100) {
                  return 'Не длиннее 100 символов';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
              items: _categoryLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) {
                      if (v != null) setState(() => _category = v);
                    },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Текст сообщения',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_contentController.text.length} симв.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Вставьте плейсхолдеры — они заменятся на данные клиента при отправке.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _variableKeys.map((key) {
                return ActionChip(
                  label: Text('{$key}', style: const TextStyle(fontSize: 12)),
                  onPressed: _saving ? null : () => _insertPlaceholder(key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Сообщение',
                hintText: 'Здравствуйте, {name}! ...',
                border: OutlineInputBorder(),
              ),
              minLines: 10,
              maxLines: 18,
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите текст сообщения';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (widget.isEdit) ...[
              Text(
                'Использований: ${widget.existing!['usageCount'] ?? 0}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(widget.isEdit ? 'Сохранить изменения' : 'Создать шаблон'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
