import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/theme.dart';

/// Минимальные токены экранов авторизации — без градиентов и декора.
abstract final class AuthDesign {
  static const Color background = AppTheme.backgroundColor;
  static const Color surface = AppTheme.surfaceColor;
  static const Color primary = AppTheme.primaryColor;
  static const Color text = AppTheme.textPrimary;
  static const Color textMuted = AppTheme.textSecondary;
  static const Color border = AppTheme.borderColor;
  static const Color error = AppTheme.errorColor;

  /// Телефон.
  static const double breakpointCompact = 600;

  /// Планшет / небольшое окно macOS.
  static const double breakpointMedium = 900;

  static const double maxContentWidth = 400;
  static const double maxFormWidth = 440;

  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(16));

  static bool isCompact(double width) => width < breakpointCompact;

  static bool isDesktop(double width) => width >= breakpointMedium;

  static double horizontalPadding(double width) {
    if (isDesktop(width)) return 48;
    if (width >= breakpointCompact) return 32;
    return 24;
  }
}
