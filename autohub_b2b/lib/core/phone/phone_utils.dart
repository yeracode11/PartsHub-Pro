import 'package:flutter/services.dart';

/// Страна для маски телефона: СНГ и США.
class PhoneCountry {
  const PhoneCountry({
    required this.iso,
    required this.name,
    required this.dial,
    required this.nationalLength,
    required this.groups,
    required this.example,
    this.group = PhoneCountryGroup.cis,
  });

  final String iso;
  final String name;
  final String dial;
  final int nationalLength;
  final List<int> groups;
  final String example;
  final PhoneCountryGroup group;

  String get dialLabel => '+$dial';
  String get buttonLabel => '$iso $dialLabel';

  static const kazakhstan = PhoneCountry(
    iso: 'KZ',
    name: 'Казахстан',
    dial: '7',
    nationalLength: 10,
    groups: [3, 3, 2, 2],
    example: '(777) 123-45-67',
  );

  static const russia = PhoneCountry(
    iso: 'RU',
    name: 'Россия',
    dial: '7',
    nationalLength: 10,
    groups: [3, 3, 2, 2],
    example: '(999) 123-45-67',
  );

  static const azerbaijan = PhoneCountry(
    iso: 'AZ',
    name: 'Азербайджан',
    dial: '994',
    nationalLength: 9,
    groups: [2, 3, 2, 2],
    example: '(50) 123-45-67',
  );

  static const armenia = PhoneCountry(
    iso: 'AM',
    name: 'Армения',
    dial: '374',
    nationalLength: 8,
    groups: [2, 3, 3],
    example: '(91) 123-456',
  );

  static const belarus = PhoneCountry(
    iso: 'BY',
    name: 'Беларусь',
    dial: '375',
    nationalLength: 9,
    groups: [2, 3, 2, 2],
    example: '(29) 123-45-67',
  );

  static const kyrgyzstan = PhoneCountry(
    iso: 'KG',
    name: 'Кыргызстан',
    dial: '996',
    nationalLength: 9,
    groups: [3, 3, 3],
    example: '(555) 123-456',
  );

  static const moldova = PhoneCountry(
    iso: 'MD',
    name: 'Молдова',
    dial: '373',
    nationalLength: 8,
    groups: [4, 4],
    example: '(6212) 3456',
  );

  static const tajikistan = PhoneCountry(
    iso: 'TJ',
    name: 'Таджикистан',
    dial: '992',
    nationalLength: 9,
    groups: [2, 3, 4],
    example: '(91) 123-4567',
  );

  static const turkmenistan = PhoneCountry(
    iso: 'TM',
    name: 'Туркменистан',
    dial: '993',
    nationalLength: 8,
    groups: [2, 2, 2, 2],
    example: '(65) 12-34-56',
  );

  static const uzbekistan = PhoneCountry(
    iso: 'UZ',
    name: 'Узбекистан',
    dial: '998',
    nationalLength: 9,
    groups: [2, 3, 2, 2],
    example: '(90) 123-45-67',
  );

  static const usa = PhoneCountry(
    iso: 'US',
    name: 'США',
    dial: '1',
    nationalLength: 10,
    groups: [3, 3, 4],
    example: '(555) 123-4567',
    group: PhoneCountryGroup.usa,
  );

  static const all = [
    azerbaijan,
    armenia,
    belarus,
    kazakhstan,
    kyrgyzstan,
    moldova,
    russia,
    tajikistan,
    turkmenistan,
    uzbekistan,
    usa,
  ];
}

enum PhoneCountryGroup { cis, usa }

/// Нормализация телефона в E.164 для стран СНГ и США.
abstract final class PhoneUtils {
  static String? normalizeToE164(
    String input, {
    PhoneCountry country = PhoneCountry.kazakhstan,
    bool nationalDigitsOnly = false,
  }) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (nationalDigitsOnly) {
      if (digits.length == country.nationalLength + country.dial.length &&
          digits.startsWith(country.dial)) {
        digits = digits.substring(country.dial.length);
      }
      if (country.dial == '7' && digits.length == 11 && digits.startsWith('8')) {
        digits = digits.substring(1);
      }
      if (digits.length != country.nationalLength) return null;
      return '+${country.dial}$digits';
    }

    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }

    final matched = _matchDial(digits);
    if (matched == null) return null;
    return '+$digits';
  }

  static PhoneCountry countryFromE164(String? e164) {
    final digits = e164?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    if (digits.isEmpty) return PhoneCountry.kazakhstan;
    final sorted = [...PhoneCountry.all]
      ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
    for (final country in sorted) {
      if (digits.startsWith(country.dial) &&
          digits.length == country.dial.length + country.nationalLength) {
        if (country.dial == '7') return PhoneCountry.kazakhstan;
        return country;
      }
    }
    return PhoneCountry.kazakhstan;
  }

  static String formatNationalForInput(String e164) {
    final country = countryFromE164(e164);
    var digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith(country.dial)) {
      digits = digits.substring(country.dial.length);
    }
    return NationalPhoneInputFormatter.maskDigits(digits, country);
  }

  static String? validationMessage(
    String? value, {
    PhoneCountry country = PhoneCountry.kazakhstan,
    bool nationalDigitsOnly = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    if (normalizeToE164(
          value,
          country: country,
          nationalDigitsOnly: nationalDigitsOnly,
        ) ==
        null) {
      return 'Формат: ${country.dialLabel} ${country.example}';
    }
    return null;
  }

  static PhoneCountry? _matchDial(String digits) {
    final sorted = [...PhoneCountry.all]
      ..sort((a, b) => b.dial.length.compareTo(a.dial.length));
    for (final country in sorted) {
      if (digits.startsWith(country.dial) &&
          digits.length == country.dial.length + country.nationalLength) {
        return country;
      }
    }
    return null;
  }
}

class NationalPhoneInputFormatter extends TextInputFormatter {
  NationalPhoneInputFormatter(this.country);

  final PhoneCountry country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();

    var national = digits;
    if (national.length == country.nationalLength + country.dial.length &&
        national.startsWith(country.dial)) {
      national = national.substring(country.dial.length);
    }
    if (country.dial == '7' &&
        national.length == 11 &&
        (national.startsWith('8') || national.startsWith('7'))) {
      national = national.substring(1);
    }

    final limited = national.length > country.nationalLength
        ? national.substring(0, country.nationalLength)
        : national;
    final masked = maskDigits(limited, country);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  static String maskDigits(String digits, PhoneCountry country) {
    if (digits.isEmpty) return '';
    final parts = <String>[];
    var index = 0;
    for (final size in country.groups) {
      if (index >= digits.length) break;
      final end = index + size > digits.length ? digits.length : index + size;
      parts.add(digits.substring(index, end));
      index = end;
    }
    final buffer = StringBuffer('(${parts.first}');
    if (parts.first.length >= country.groups.first) buffer.write(')');
    for (var i = 1; i < parts.length; i++) {
      buffer.write(i == 1 ? ' ' : '-');
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }
}
