import 'package:autohub_b2b/services/api/api_user_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:autohub_b2b/blocs/auth/auth_bloc.dart';
import 'package:autohub_b2b/blocs/auth/auth_state.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/user_model.dart';
import 'package:autohub_b2b/screens/whatsapp/whatsapp_template_editor_page.dart';
import 'package:autohub_b2b/utils/auth_guard.dart';
import 'package:autohub_b2b/utils/dialog_helper.dart';

/// Вкладка управления шаблонами WhatsApp: список, создание, правка, удаление.
class WhatsAppTemplatesTab extends StatelessWidget {
  final Dio dio;
  final List<Map<String, dynamic>> templates;
  final Future<void> Function() onReload;
  final bool isMobile;
  final Future<void> Function() onCreateDefaults;

  const WhatsAppTemplatesTab({
    super.key,
    required this.dio,
    required this.templates,
    required this.onReload,
    required this.isMobile,
    required this.onCreateDefaults,
  });

  static String _categoryLabel(String? raw) {
    const labels = {
      'promo': 'Акции',
      'reminder': 'Напоминания',
      'notification': 'Уведомления',
      'greeting': 'Поздравления',
      'custom': 'Свой',
    };
    final k = raw?.toString().toLowerCase();
    return labels[k] ?? (k ?? '—');
  }

  Future<void> _openEditor(
    BuildContext context,
    Map<String, dynamic>? existing,
  ) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => WhatsAppTemplateEditorPage(
          dio: dio,
          existing: existing,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      await onReload();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> t) async {
    if (!await ensureAuthenticated(context)) return;
    if (!context.mounted) return;

    await DialogHelper.showConfirm(
      context: context,
      title: 'Удалить шаблон?',
      message:
          '«${t['name']}» будет скрыт из списка. Рассылки по этому шаблону станут недоступны.',
      confirmText: 'Удалить',
      isDestructive: true,
      onConfirm: (dialogCtx) async {
        Navigator.pop(dialogCtx);
        try {
          final id = t['id'];
          await dio.delete('/api/whatsapp/templates/$id');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Шаблон удалён'),
                backgroundColor: Colors.green,
              ),
            );
            await onReload();
          }
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFacingApiMessage(e, prefix: 'Ошибка удаления')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final canEdit = authState is AuthAuthenticated &&
            (authState.user.role == UserRole.owner ||
                authState.user.role == UserRole.manager);
        final canLoadDefaults = authState is AuthAuthenticated &&
            authState.user.role == UserRole.owner;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 12, isMobile ? 12 : 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Шаблоны сообщений',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Тексты для рассылки. В фигурных скобках — поля, которые подставятся автоматически.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canLoadDefaults)
                    TextButton.icon(
                      onPressed: () => onCreateDefaults(),
                      icon: const Icon(Icons.auto_fix_high, size: 20),
                      label: Text(isMobile ? 'Набор' : 'Шаблоны по умолчанию'),
                    ),
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _openEditor(context, null),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(isMobile ? 'Новый' : 'Новый шаблон'),
                    ),
                  ],
                ],
              ),
            ),
            if (!canEdit)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
                child: Card(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  child: const ListTile(
                    leading: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    title: Text('Только владелец и менеджер могут создавать и менять шаблоны.'),
                  ),
                ),
              ),
            Expanded(
              child: templates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.text_snippet_outlined,
                              size: isMobile ? 56 : 72,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Пока нет шаблонов',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Добавьте свой текст или загрузите готовый набор для автобизнеса.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            if (canEdit) ...[
                              FilledButton.icon(
                                onPressed: () => _openEditor(context, null),
                                icon: const Icon(Icons.add),
                                label: const Text('Создать шаблон'),
                              ),
                              if (canLoadDefaults) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => onCreateDefaults(),
                                  icon: const Icon(Icons.downloading),
                                  label: const Text('Загрузить шаблоны по умолчанию'),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 12 : 20,
                        8,
                        isMobile ? 12 : 20,
                        24,
                      ),
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final t = templates[index];
                        final name = t['name']?.toString() ?? 'Без названия';
                        final content = t['content']?.toString() ?? '';
                        final usage = t['usageCount'] ?? 0;

                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: canEdit
                                ? () => _openEditor(context, t)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    _categoryLabel(
                                                      t['category']?.toString(),
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  padding: EdgeInsets.zero,
                                                ),
                                                Text(
                                                  'Использований: $usage',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (canEdit)
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _openEditor(context, t);
                                            } else if (value == 'delete') {
                                              _confirmDelete(context, t);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: ListTile(
                                                leading: Icon(Icons.edit_outlined),
                                                title: Text('Редактировать'),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: ListTile(
                                                leading: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                title: Text('Удалить'),
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    content,
                                    maxLines: isMobile ? 4 : 6,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isMobile ? 13 : 14,
                                      height: 1.35,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
