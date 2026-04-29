import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
              mOptions: MacOsOptions(),
            );

  final FlutterSecureStorage _storage;

  Future<void> writeAccessToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: StorageKeys.accessToken);
      return;
    }
    await _storage.write(key: StorageKeys.accessToken, value: token);
  }

  Future<String?> readAccessToken() => _storage.read(key: StorageKeys.accessToken);

  Future<void> writeRefreshToken(String? token) async {
    if (token == null || token.isEmpty) {
      await _storage.delete(key: StorageKeys.refreshToken);
      return;
    }
    await _storage.write(key: StorageKeys.refreshToken, value: token);
  }

  Future<String?> readRefreshToken() => _storage.read(key: StorageKeys.refreshToken);

  Future<void> clearAll() async {
    await _storage.delete(key: StorageKeys.accessToken);
    await _storage.delete(key: StorageKeys.refreshToken);
  }
}
