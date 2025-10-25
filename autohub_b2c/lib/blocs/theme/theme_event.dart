import 'package:flutter/material.dart';

abstract class ThemeEvent {}

class ThemeLoadRequested extends ThemeEvent {}

class ThemeModeChanged extends ThemeEvent {
  final ThemeMode themeMode;

  ThemeModeChanged(this.themeMode);
}
