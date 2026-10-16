import 'package:autohub_b2b/core/phone/phone_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = NationalPhoneInputFormatter(PhoneCountry.kazakhstan);

  TextEditingValue backspace(String text) {
    final old = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    final next = text.substring(0, text.length - 1);
    return formatter.formatEditUpdate(
      old,
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      ),
    );
  }

  test('стирание до конца проходит через разделители маски', () {
    var value = const TextEditingValue(text: '(777) 123-45-67');
    final seen = <String>[];
    while (value.text.isNotEmpty) {
      value = backspace(value.text);
      seen.add(value.text);
      expect(seen.length, lessThan(30), reason: 'курсор застрял: $seen');
    }
    expect(value.text, '');
  });

  test('стёртая «)» удаляет последнюю цифру кода', () {
    expect(backspace('(777)').text, '(77');
  });

  test('стёртый пробел и дефис удаляют предыдущую цифру', () {
    expect(backspace('(777) ').text, '(77');
    expect(backspace('(777) 123-').text, '(777) 12');
  });

  test('обычный ввод и вставка работают как раньше', () {
    final typed = formatter.formatEditUpdate(
      const TextEditingValue(text: '(777'),
      const TextEditingValue(text: '(7771'),
    );
    expect(typed.text, '(777) 1');
    final pasted = formatter.formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '+7 777 123 45 67'),
    );
    expect(pasted.text, '(777) 123-45-67');
  });
}
