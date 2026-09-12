import 'package:flutter/services.dart';

/// Утилиты телефона Казахстан (+7).
abstract final class PhoneUtils {
  static const String countryCode = '+7';
  static const int nationalDigits = 10;

  /// E.164: +77771234567
  static String? normalizeToE164(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    String normalized;
    if (digits.length == 11 && digits.startsWith('7')) {
      normalized = digits;
    } else if (digits.length == 11 && digits.startsWith('8')) {
      normalized = '7${digits.substring(1)}';
    } else if (digits.length == 10) {
      normalized = '7$digits';
    } else {
      return null;
    }

    if (normalized.length != 11 || !normalized.startsWith('7')) {
      return null;
    }

    return '+$normalized';
  }

  static bool isValidKzPhone(String input) => normalizeToE164(input) != null;

  static String? validationMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    if (!isValidKzPhone(value)) {
      return 'Формат: +7 (XXX) XXX-XX-XX';
    }
    return null;
  }
}

/// Маска +7 (XXX) XXX-XX-XX для Казахстана.
class KazakhstanPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    var normalized = digits;
    if (normalized.startsWith('8') && normalized.length > 1) {
      normalized = '7${normalized.substring(1)}';
    } else if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }

    final limited = normalized.length > 11
        ? normalized.substring(0, 11)
        : normalized;

    final masked = _mask(limited);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  static String _mask(String digits) {
    final buffer = StringBuffer('+7');
    if (digits.length > 1) {
      final area = digits.substring(1, digits.length > 4 ? 4 : digits.length);
      buffer.write(' ($area');
      if (digits.length >= 4) buffer.write(')');
    }
    if (digits.length > 4) {
      final first = digits.substring(4, digits.length > 7 ? 7 : digits.length);
      buffer.write(' $first');
    }
    if (digits.length > 7) {
      final second = digits.substring(7, digits.length > 9 ? 9 : digits.length);
      buffer.write('-$second');
    }
    if (digits.length > 9) {
      final third = digits.substring(9, digits.length > 11 ? 11 : digits.length);
      buffer.write('-$third');
    }
    return buffer.toString();
  }
}
