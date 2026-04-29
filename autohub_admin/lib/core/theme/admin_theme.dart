import 'package:flutter/material.dart';

class AdminTheme {
  AdminTheme._();

  static ThemeData light() {
    const seed = Color(0xFF1565C0);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}
