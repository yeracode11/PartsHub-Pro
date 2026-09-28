import 'package:flutter/services.dart';

enum AuthPhoneRegion { kz, us }

/// Нормализация телефона KZ (+7) и US/CA (+1).
abstract final class PhoneUtils {
  static const String kzCountryCode = '+7';
  static const String usCountryCode = '+1';

  /// E.164: +77771234567 или +15551234567
  static String? normalizeToE164(
    String input, {
    AuthPhoneRegion region = AuthPhoneRegion.kz,
  }) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (region == AuthPhoneRegion.us ||
        (digits.startsWith('1') && digits.length == 11)) {
      return _normalizeUs(digits, region);
    }

    return _normalizeKz(digits);
  }

  static String? _normalizeUs(String digits, AuthPhoneRegion region) {
    String national;
    if (digits.length == 11 && digits.startsWith('1')) {
      national = digits;
    } else if (digits.length == 10) {
      national = '1$digits';
    } else if (region == AuthPhoneRegion.us && digits.length <= 10) {
      return null;
    } else {
      return null;
    }

    if (national.length != 11 || !national.startsWith('1')) {
      return null;
    }
    return '+$national';
  }

  static String? _normalizeKz(String digits) {
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

  static bool isValidPhone(String input, {AuthPhoneRegion region = AuthPhoneRegion.kz}) {
    return normalizeToE164(input, region: region) != null;
  }

  static AuthPhoneRegion regionFromE164(String? e164) {
    if (e164 != null && e164.trim().startsWith('+1')) {
      return AuthPhoneRegion.us;
    }
    return AuthPhoneRegion.kz;
  }

  /// Маска для поля ввода из E.164 (+77771234567 / +15551234567).
  static String formatForInput(String e164) {
    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return e164;

    if (e164.startsWith('+1') || (digits.startsWith('1') && digits.length == 11)) {
      var normalized = digits;
      if (!normalized.startsWith('1')) {
        normalized = '1$normalized';
      }
      return UsPhoneInputFormatter.maskDigits(normalized);
    }

    var normalized = digits;
    if (normalized.startsWith('8') && normalized.length > 1) {
      normalized = '7${normalized.substring(1)}';
    } else if (!normalized.startsWith('7')) {
      normalized = '7$normalized';
    }
    return KazakhstanPhoneInputFormatter.maskDigits(normalized);
  }

  static String? validationMessage(
    String? value, {
    AuthPhoneRegion region = AuthPhoneRegion.kz,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    if (!isValidPhone(value, region: region)) {
      return region == AuthPhoneRegion.us
          ? 'Формат: +1 (555) 123-4567'
          : 'Формат: +7 (777) 123-45-67';
    }
    return null;
  }
}

/// Маска +7 (XXX) XXX-XX-XX
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

    final masked = maskDigits(limited);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  static String maskDigits(String digits) {
    return _maskKz(digits);
  }

  static String _maskKz(String digits) {
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

/// Маска +1 (XXX) XXX-XXXX
class UsPhoneInputFormatter extends TextInputFormatter {
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
    if (!normalized.startsWith('1')) {
      normalized = '1$normalized';
    }

    final limited = normalized.length > 11
        ? normalized.substring(0, 11)
        : normalized;

    final masked = maskDigits(limited);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  static String maskDigits(String digits) {
    return _maskUs(digits);
  }

  static String _maskUs(String digits) {
    final buffer = StringBuffer('+1');
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
      final second = digits.substring(7, digits.length > 11 ? 11 : digits.length);
      buffer.write('-$second');
    }
    return buffer.toString();
  }
}
