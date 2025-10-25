import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  static const String _themeKey = 'theme_mode';

  ThemeBloc() : super(_getInitialState()) {
    on<ThemeLoadRequested>(_onLoadRequested);
    on<ThemeModeChanged>(_onThemeModeChanged);
  }

  static ThemeState _getInitialState() {
    // По умолчанию светлая тема
    return ThemeState(
      themeMode: ThemeMode.light,
      themeData: AppTheme.lightTheme,
    );
  }

  Future<void> _onLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeModeIndex = prefs.getInt(_themeKey) ?? ThemeMode.light.index;

      final themeMode = ThemeMode.values[themeModeIndex];
      final themeData = _getThemeData(themeMode);

      emit(ThemeState(
        themeMode: themeMode,
        themeData: themeData,
      ));
    } catch (e) {
      // В случае ошибки используем светлую тему
      emit(state.copyWith(
        themeMode: ThemeMode.light,
        themeData: AppTheme.lightTheme,
      ));
    }
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<ThemeState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, event.themeMode.index);

      final themeData = _getThemeData(event.themeMode);

      emit(state.copyWith(
        themeMode: event.themeMode,
        themeData: themeData,
      ));
    } catch (e) {
      // В случае ошибки не меняем состояние
    }
  }

  ThemeData _getThemeData(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return AppTheme.lightTheme;
      case ThemeMode.dark:
        return AppTheme.darkTheme;
      case ThemeMode.system:
        // Для system режима по умолчанию используем светлую тему
        // В реальном приложении нужно отслеживать системную тему
        return AppTheme.lightTheme;
    }
  }

  // Метод для переключения между светлой и темной темой
  void toggleTheme() {
    final newThemeMode = state.themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;

    add(ThemeModeChanged(newThemeMode));
  }
}
