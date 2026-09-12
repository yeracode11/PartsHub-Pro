import 'package:intl/intl.dart';

abstract final class Formatters {
  static NumberFormat? _price;
  static DateFormat? _date;
  static DateFormat? _dateTime;

  static void ensureInitialized() {
    _price ??= NumberFormat('#,###', 'ru');
    _date ??= DateFormat('d MMM yyyy', 'ru');
    _dateTime ??= DateFormat('d MMM, HH:mm', 'ru');
  }

  static String price(double value) {
    ensureInitialized();
    return '${_price!.format(value)} ₸';
  }

  static String date(DateTime value) {
    ensureInitialized();
    return _date!.format(value);
  }

  static String dateTime(DateTime value) {
    ensureInitialized();
    return _dateTime!.format(value);
  }

  static String mileage(int value) {
    ensureInitialized();
    return '${_price!.format(value)} км';
  }
}
