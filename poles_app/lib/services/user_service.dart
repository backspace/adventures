import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _teamIdKey = 'team_id';
  static const String _teamNameKey = 'team_name';
  static const String _accessTokenKey = 'access_token';
  static const String _renewalTokenKey = 'renewal_token';

  static Future<void> setUserData(
    String userId,
    String email, {
    String? name,
    String? teamId,
    String? teamName,
  }) async {
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _userEmailKey, value: email);
    if (name != null) await _storage.write(key: _userNameKey, value: name);
    if (teamId != null) await _storage.write(key: _teamIdKey, value: teamId);
    if (teamName != null) await _storage.write(key: _teamNameKey, value: teamName);
  }

  static Future<void> setTokens(String accessToken, String renewalToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _renewalTokenKey, value: renewalToken);
  }

  static Future<String?> getUserId() => _storage.read(key: _userIdKey);
  static Future<String?> getUserEmail() => _storage.read(key: _userEmailKey);
  static Future<String?> getUserName() => _storage.read(key: _userNameKey);
  static Future<String?> getTeamId() => _storage.read(key: _teamIdKey);
  static Future<String?> getTeamName() => _storage.read(key: _teamNameKey);
  static Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  static Future<String?> getRenewalToken() => _storage.read(key: _renewalTokenKey);

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearUserData() async {
    await _storage.deleteAll();
  }
}
