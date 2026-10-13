import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autohub_b2b/services/local_data_guard.dart';

void main() {
  late int clears;
  Future<void> clear() async => clears++;

  setUp(() => clears = 0);

  test('вход в ту же организацию данные не трогает', () async {
    SharedPreferences.setMockInitialValues({'local_data_owner_org': 'org-a'});
    await LocalDataGuard.ensureOwner('org-a', clear: clear);
    expect(clears, 0);
  });

  test('вход в другую организацию стирает кэш и очередь прежней', () async {
    SharedPreferences.setMockInitialValues({'local_data_owner_org': 'org-a'});
    await LocalDataGuard.ensureOwner('org-b', clear: clear);
    expect(clears, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('local_data_owner_org'), 'org-b');
  });

  test('кэш без владельца: при входе стираем, при восстановлении сессии сохраняем', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalDataGuard.ensureOwner('org-a', clear: clear);
    expect(clears, 1);

    SharedPreferences.setMockInitialValues({});
    await LocalDataGuard.ensureOwner('org-a', trustUnknownOwner: true, clear: clear);
    expect(clears, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('local_data_owner_org'), 'org-a');
  });
}
