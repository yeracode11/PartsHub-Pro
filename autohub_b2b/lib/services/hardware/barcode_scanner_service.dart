import 'dart:async';
import 'package:flutter/services.dart';

/// Сервис для работы со сканером штрих-кодов
/// 
/// Большинство USB сканеров работают как HID клавиатура,
/// поэтому мы просто слушаем ввод в текстовое поле.
/// 
/// Для автоматического поиска товара по штрих-коду используйте
/// метод `onBarcodeScanned` в TextField с `onChanged`.
class BarcodeScannerService {
  static final BarcodeScannerService _instance = BarcodeScannerService._internal();
  factory BarcodeScannerService() => _instance;
  BarcodeScannerService._internal();

  Timer? _debounceTimer;
  String _buffer = '';
  final Duration _scanTimeout = const Duration(milliseconds: 100);

  /// Обработчик отсканированного штрих-кода
  Function(String)? onBarcodeScanned;

  /// Обработка ввода символов (вызывается из TextField.onChanged)
  /// 
  /// Сканеры обычно вводят данные очень быстро (все символы за ~100ms),
  /// поэтому мы собираем символы в буфер и обрабатываем их как один штрих-код.
  void handleInput(String value) {
    // Если значение короче предыдущего, значит поле было очищено
    if (value.length < _buffer.length) {
      _buffer = value;
      _debounceTimer?.cancel();
      return;
    }

    // Добавляем новые символы в буфер
    _buffer = value;

    // Отменяем предыдущий таймер
    _debounceTimer?.cancel();

    // Устанавливаем новый таймер
    _debounceTimer = Timer(_scanTimeout, () {
      if (_buffer.isNotEmpty && onBarcodeScanned != null) {
        onBarcodeScanned!(_buffer);
      }
      _buffer = '';
    });
  }

  /// Очистка буфера (вызывается при потере фокуса)
  void clearBuffer() {
    _debounceTimer?.cancel();
    _buffer = '';
  }

  /// Воспроизведение звукового сигнала (опционально)
  /// 
  /// Можно использовать для обратной связи при успешном сканировании
  Future<void> playBeep() async {
    // Для Windows можно использовать системный звук через платформенный канал
    // Пока оставляем пустым, можно добавить позже
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}

