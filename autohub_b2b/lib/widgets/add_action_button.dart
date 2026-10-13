import 'package:flutter/material.dart';

/// Единое действие «Добавить» для списков: на телефоне иконка «+»,
/// на широком экране кнопка с подписью.
class AddActionButton extends StatelessWidget {
  const AddActionButton({
    super.key,
    required this.onPressed,
    this.label = 'Добавить',
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final String label;
  final String? tooltip;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 768;

  @override
  Widget build(BuildContext context) {
    if (isWide(context)) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label),
      );
    }
    return IconButton(
      icon: const Icon(Icons.add),
      tooltip: tooltip ?? label,
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    );
  }
}
