import 'package:flutter/material.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';

class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    this.title = 'Auto+ Pro',
    this.subtitle = 'Управление автобизнесом',
    this.sectionTitle,
    required this.form,
    this.leading,
    this.footer,
    this.errorMessage,
    this.wideForm = false,
  });

  final String title;
  final String subtitle;
  final String? sectionTitle;
  final Widget form;
  final Widget? leading;
  final Widget? footer;
  final String? errorMessage;

  /// Длинные формы (регистрация): шире колонка, выравнивание сверху.
  final bool wideForm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthDesign.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = AuthDesign.isDesktop(width);
            final maxWidth = wideForm
                ? AuthDesign.maxFormWidth
                : AuthDesign.maxContentWidth;
            final hPad = AuthDesign.horizontalPadding(width);
            final centerVertically = !wideForm && isDesktop;

            final body = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment:
                  centerVertically ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (leading != null) SizedBox(height: isDesktop ? 0 : 8),
                if (!isDesktop && leading != null) leading!,
                SizedBox(height: isDesktop ? 8 : 16),
                Center(
                  child: Image.asset(
                    'assets/icons/auto-plus-logo.png',
                    width: isDesktop ? 64 : 56,
                    height: isDesktop ? 64 : 56,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: isDesktop ? 24 : 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 26 : 24,
                    fontWeight: FontWeight.w600,
                    color: AuthDesign.text,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AuthDesign.textMuted,
                    height: 1.4,
                  ),
                ),
                if (sectionTitle != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    sectionTitle!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AuthDesign.text,
                    ),
                  ),
                ] else
                  SizedBox(height: isDesktop ? 36 : 32),
                if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AuthDesign.error,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                form,
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
                SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
              ],
            );

            Widget panel = ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minHeight: centerVertically ? constraints.maxHeight - hPad * 2 : 0,
              ),
              child: body,
            );

            if (isDesktop) {
              panel = Container(
                constraints: BoxConstraints(maxWidth: maxWidth + 64),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: AuthDesign.surface,
                  borderRadius: AuthDesign.panelRadius,
                  border: Border.all(color: AuthDesign.border),
                ),
                child: panel,
              );
            }

            return Stack(
              children: [
                Align(
                  alignment:
                      wideForm ? Alignment.topCenter : Alignment.center,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      hPad,
                      wideForm ? 16 : (isDesktop ? 24 : 8),
                      hPad,
                      24,
                    ),
                    child: panel,
                  ),
                ),
                if (isDesktop && leading != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: leading!,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AuthIconButton extends StatelessWidget {
  const AuthIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AuthDesign.textMuted),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class AuthLinkRow extends StatelessWidget {
  const AuthLinkRow({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onAction,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: const TextStyle(color: AuthDesign.textMuted, fontSize: 14),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
