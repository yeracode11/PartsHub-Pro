import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(_getInitialState()) {
    on<ThemeLoadRequested>(_onLoadRequested);
  }

  static ThemeState _getInitialState() {
    // Всегда используем светлую тему
    return ThemeState(
      themeMode: ThemeMode.light,
      themeData: AppTheme.lightTheme,
    );
  }

  Future<void> _onLoadRequested(
    ThemeLoadRequested event,
    Emitter<ThemeState> emit,
  ) async {
    // Всегда используем светлую тему
    emit(ThemeState(
      themeMode: ThemeMode.light,
      themeData: AppTheme.lightTheme,
    ));
  }
}
