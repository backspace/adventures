import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userIsAdminKey = 'user_is_admin';
  static const String _accessTokenKey = 'access_token';
  static const String _renewalTokenKey = 'renewal_token';
  static const String _userNameKey = 'user_name';

  static Future<void> setUserData(String userId, String email, bool isAdmin,
      {String? name}) async {
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);
    await _storage.write(key: _userIsAdminKey, value: isAdmin.toString());
    if (name != null) {
      await _storage.write(key: _userNameKey, value: name);
    }
  }

  static Future<void> setTokens(String accessToken, String renewalToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _renewalTokenKey, value: renewalToken);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  static Future<String?> getUserEmail() async {
    return await _storage.read(key: _userEmailKey);
  }

  static Future<bool> getUserIsAdmin() async {
    final isAdmin = await _storage.read(key: _userIsAdminKey);
    return isAdmin == 'true';
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<String?> getRenewalToken() async {
    return await _storage.read(key: _renewalTokenKey);
  }

  static Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  static Future<void> setUserName(String name) async {
    await _storage.write(key: _userNameKey, value: name);
  }

  static Future<void> clearUserData() async {
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userNameKey);
    await _storage.delete(key: _userIsAdminKey);
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _renewalTokenKey);
  }
}
