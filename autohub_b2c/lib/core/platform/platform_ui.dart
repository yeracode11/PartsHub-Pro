import 'package:flutter/material.dart';
import '../design/app_spacing.dart';

abstract final class PlatformUI {
  static double bottomContentInset(BuildContext context) {
    final padding = MediaQuery.paddingOf(context).bottom;
    return padding + AppSpacing.bottomNavHeight;
  }
}
