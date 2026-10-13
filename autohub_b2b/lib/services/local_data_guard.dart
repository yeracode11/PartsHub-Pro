import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:autohub_b2b/services/offline_queue.dart';
import 'package:autohub_b2b/services/service_locator.dart';

/// Не даёт данным одной организации пережить вход в другую на том же устройстве.
///
/// Локальная база (товары, заказы, клиенты) и офлайн-очередь не привязаны к аккаунту.
/// Без очистки новый пользователь видел бы кэш прежней организации, а неотправленные
/// офлайн-изменения ушли бы на сервер с его токеном — в чужую организацию.
class LocalDataGuard {
  static const _ownerKey = 'local_data_owner_org';

  /// Вызывать до первой синхронизации после входа.
  ///
  /// [trustUnknownOwner] — данные без отметки владельца (установка до этой проверки)
  /// считать данными текущей организации. true только для восстановления сессии
  /// при запуске: тот же пользователь, что и раньше. При явном входе — false,
  /// потому что неизвестно, чей это кэш.
  static Future<void> ensureOwner(
    String? organizationId, {
    bool trustUnknownOwner = false,
    @visibleForTesting Future<void> Function()? clear,
  }) async {
    if (organizationId == null || organizationId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(_ownerKey);
    if (owner == organizationId) return;

    final unknown = owner == null;
    if (!unknown || !trustUnknownOwner) {
      await (clear ?? clearLocalData)();
      debugPrint('[LocalDataGuard] cleared local data of another organization');
    }
    await prefs.setString(_ownerKey, organizationId);
  }

  static Future<void> clearLocalData() async {
    await ServiceLocator().database.clearOrganizationData();
    await OfflineQueue().clearCache();
  }
}
