import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService() : _storage = const FlutterSecureStorage();

  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserPhone = 'auth_user_phone';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? phoneNumber,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    if (phoneNumber != null) {
      await _storage.write(key: _keyUserPhone, value: phoneNumber);
    }
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: _keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _keyRefreshToken);
  }

  Future<String?> getUserPhone() async {
    return _storage.read(key: _keyUserPhone);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

