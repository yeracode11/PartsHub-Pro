import 'package:flutter/material.dart';

/// Утилита для адаптивных диалогов: на мобильных — full-screen или bottom sheet,
/// на десктопе — AlertDialog.
class DialogHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  /// Показывает диалог подтверждения. На мобильных — bottom sheet, на десктопе — AlertDialog.
  /// [onConfirm] вызывается при нажатии кнопки подтверждения. Caller должен сам закрыть диалог (Navigator.pop).
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Отмена',
    String confirmText = 'Подтвердить',
    bool isDestructive = false,
    required Future<void> Function(BuildContext dialogContext) onConfirm,
  }) async {
    final mobile = isMobile(context);
    if (mobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(cancelText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await onConfirm(ctx);
                        },
                        style: isDestructive
                            ? FilledButton.styleFrom(backgroundColor: Colors.red)
                            : null,
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () async {
              await onConfirm(ctx);
            },
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Простое подтверждение с возвратом bool (без side-effect в onConfirm).
  static Future<bool?> showConfirmSimple({
    required BuildContext context,
    required String title,
    required String message,
    String cancelText = 'Отмена',
    String confirmText = 'Подтвердить',
    bool isDestructive = false,
  }) async {
    final mobile = isMobile(context);
    if (mobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(cancelText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: isDestructive
                            ? FilledButton.styleFrom(backgroundColor: Colors.red)
                            : null,
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}
