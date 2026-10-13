import 'package:flutter/material.dart';

/// Канал от экрана раздела к AppBar мобильной оболочки (main.dart).
///
/// На телефоне у раздела одна шапка — оболочки. Экран не рисует свой AppBar,
/// а передаёт кнопки через [ShellActions]; оболочка показывает их справа.
class ShellActionsScope extends InheritedWidget {
  const ShellActionsScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final ValueNotifier<List<Widget>> actions;

  static ValueNotifier<List<Widget>>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellActionsScope>()?.actions;

  @override
  bool updateShouldNotify(ShellActionsScope oldWidget) =>
      actions != oldWidget.actions;
}

/// Публикует [actions] в AppBar оболочки, пока экран показан.
/// Вне оболочки (или на широком экране, где её AppBar нет) ничего не делает.
class ShellActions extends StatefulWidget {
  const ShellActions({super.key, required this.actions, required this.child});

  final List<Widget> actions;
  final Widget child;

  @override
  State<ShellActions> createState() => _ShellActionsState();
}

class _ShellActionsState extends State<ShellActions> {
  ValueNotifier<List<Widget>>? _notifier;
  List<Widget>? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notifier = ShellActionsScope.maybeOf(context);
    _publish();
  }

  @override
  void didUpdateWidget(ShellActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  // Оболочка перестраивается от notifier, поэтому меняем его после кадра,
  // а не во время build экрана.
  void _publish() {
    final notifier = _notifier;
    if (notifier == null) return;
    final actions = widget.actions;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _published = actions;
      notifier.value = actions;
    });
  }

  @override
  void dispose() {
    final notifier = _notifier;
    final published = _published;
    if (notifier != null && published != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Новый экран мог уже опубликовать свои кнопки — их не трогаем.
        if (identical(notifier.value, published)) notifier.value = const [];
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
