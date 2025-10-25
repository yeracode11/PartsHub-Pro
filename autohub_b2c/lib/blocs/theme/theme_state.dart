import 'package:flutter/material.dart';

class ThemeState {
  final ThemeMode themeMode;
  final ThemeData themeData;

  const ThemeState({
    required this.themeMode,
    required this.themeData,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    ThemeData? themeData,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      themeData: themeData ?? this.themeData,
    );
  }
}
