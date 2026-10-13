import 'package:flutter/material.dart';

class AppTheme {
  // Цветовая палитра
  static const Color primaryColor = Color(0xFF2563EB); // Синий
  static const Color secondaryColor = successColor;
  static const Color accentColor = warningColor;
  static const Color errorColor = Color(0xFFDC2626);

  // Семантическая палитра — единственный источник цветов статусов и акцентов.
  // Экраны не должны брать Colors.green/orange/... напрямую.
  static const Color successColor = Color(0xFF059669); // готово, оплачено
  static const Color warningColor = Color(0xFFD97706); // ожидание, внимание
  static const Color violetColor = Color(0xFF7C3AED); // в работе, бронь
  // «Мягкие» варианты (~10% и ~30%) для фонов и рамок; const, чтобы работать в const-виджетах.
  static const Color primarySoft = Color(0x1A2563EB);
  static const Color primaryBorder = Color(0x4D2563EB);
  static const Color successSoft = Color(0x1A059669);
  static const Color successBorder = Color(0x4D059669);
  static const Color warningSoft = Color(0x1AD97706);
  static const Color warningBorder = Color(0x4DD97706);
  static const Color errorSoft = Color(0x1ADC2626);
  static const Color errorBorder = Color(0x4DDC2626);
  static const Color violetSoft = Color(0x1A7C3AED);
  static const Color violetBorder = Color(0x4D7C3AED);

  /// Заголовок раздела на экранах карточек и форм.
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
  );

  /// Цвет статуса заказа — один для списка, карточки и дашборда.
  static Color orderStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'ready':
        return successColor;
      case 'processing':
        return primaryColor;
      case 'reserved':
      case 'picking':
        return violetColor;
      case 'delivered':
      case 'returned':
        return textSecondary;
      case 'cancelled':
        return errorColor;
      default:
        return warningColor;
    }
  }

  static const Color backgroundColor = Color(0xFFF9FAFB);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFFE5E7EB);

  // Градиенты
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [successColor, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warningColor, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // AppBar
      // Все экраны получают одинаковый белый AppBar с тонкой линией снизу.
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        shape: Border(bottom: BorderSide(color: borderColor)),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        color: surfaceColor,
        clipBehavior: Clip.antiAlias,
      ),

      // Диалоги (попапы)
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent, // убираем розовый/цветной оттенок
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: const TextStyle(fontSize: 14, color: textSecondary),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // InputDecoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      // Кнопки: одна форма и размер для Filled/Elevated/Outlined,
      // чтобы «Отмена» и «Сохранить» рядом выглядели как пара.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textPrimary,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textSecondary,
          letterSpacing: 0,
        ),
        // Размеры title/label берутся из Material 3, обнуляем только трекинг:
        // разреженный текст M3 на iOS выглядит чужеродно.
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(letterSpacing: 0),
        titleSmall: TextStyle(letterSpacing: 0),
        labelLarge: TextStyle(letterSpacing: 0),
        labelMedium: TextStyle(letterSpacing: 0),
        labelSmall: TextStyle(letterSpacing: 0),
      ),

      // Переключатели периода и фильтров
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primaryColor.withValues(alpha: 0.1)
                : surfaceColor,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primaryColor
                : textPrimary,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: borderColor)),
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),

      // NavigationRail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceColor,
        selectedIconTheme: const IconThemeData(color: primaryColor, size: 28),
        unselectedIconTheme: IconThemeData(
          color: textSecondary.withValues(alpha: 0.6),
          size: 24,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        elevation: 0,
        indicatorColor: primaryColor.withValues(alpha: 0.1),
      ),
    );
  }
}
