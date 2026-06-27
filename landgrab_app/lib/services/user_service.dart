import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persisted user/auth state, namespaced per API root so that switching
/// environments doesn't drop the session you had in another env.
///
/// The `apiRoot` field must be set (via [setCurrentApiRoot]) before any
/// session-related read/write. The api root override (which controls which
/// env we're using) is the one global key, since it isn't tied to any env.
class UserService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Global (env-independent) keys
  static const String _apiRootOverrideKey = 'api_root_override';

  // Per-env key suffixes — actual storage key is `${suffix}:${apiRoot}`
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _teamIdKey = 'team_id';
  static const String _teamNameKey = 'team_name';
  static const String _rolesKey = 'roles';
  static const String _accessTokenKey = 'access_token';
  static const String _renewalTokenKey = 'renewal_token';

  static String? _currentApiRoot;

  /// Called by the app on boot and on every env switch.
  static void setCurrentApiRoot(String apiRoot) {
    _currentApiRoot = apiRoot;
  }

  static String _key(String suffix) {
    final root = _currentApiRoot;
    if (root == null || root.isEmpty) {
      throw StateError(
        'UserService called before setCurrentApiRoot. App.dart should set it during bootstrap.',
      );
    }
    return '$suffix:$root';
  }

  static Future<void> setUserData(
    String userId,
    String email, {
    String? name,
    String? teamId,
    String? teamName,
    List<String>? roles,
  }) async {
    await _storage.write(key: _key(_userIdKey), value: userId);
    await _storage.write(key: _key(_userEmailKey), value: email);
    if (name != null) await _storage.write(key: _key(_userNameKey), value: name);
    if (teamId != null) await _storage.write(key: _key(_teamIdKey), value: teamId);
    if (teamName != null) await _storage.write(key: _key(_teamNameKey), value: teamName);
    if (roles != null) {
      await _storage.write(key: _key(_rolesKey), value: roles.join(','));
    }
  }

  static Future<void> setTokens(String accessToken, String renewalToken) async {
    await _storage.write(key: _key(_accessTokenKey), value: accessToken);
    await _storage.write(key: _key(_renewalTokenKey), value: renewalToken);
  }

  static Future<String?> getUserId() => _storage.read(key: _key(_userIdKey));
  static Future<String?> getUserEmail() => _storage.read(key: _key(_userEmailKey));
  static Future<String?> getUserName() => _storage.read(key: _key(_userNameKey));
  static Future<String?> getTeamId() => _storage.read(key: _key(_teamIdKey));
  static Future<String?> getTeamName() => _storage.read(key: _key(_teamNameKey));
  static Future<String?> getAccessToken() =>
      _storage.read(key: _key(_accessTokenKey));
  static Future<String?> getRenewalToken() =>
      _storage.read(key: _key(_renewalTokenKey));

  static Future<List<String>> getRoles() async {
    final raw = await _storage.read(key: _key(_rolesKey));
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',');
  }

  static Future<bool> hasRole(String role) async {
    final roles = await getRoles();
    return roles.contains(role);
  }

  static Future<String?> getApiRootOverride() =>
      _storage.read(key: _apiRootOverrideKey);

  static Future<void> setApiRootOverride(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _apiRootOverrideKey);
    } else {
      await _storage.write(key: _apiRootOverrideKey, value: value);
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Clears the session for the currently-active env only. Tokens stored
  /// against other envs remain — switching back will pick them up.
  static Future<void> clearUserData() async {
    await _storage.delete(key: _key(_userIdKey));
    await _storage.delete(key: _key(_userEmailKey));
    await _storage.delete(key: _key(_userNameKey));
    await _storage.delete(key: _key(_teamIdKey));
    await _storage.delete(key: _key(_teamNameKey));
    await _storage.delete(key: _key(_rolesKey));
    await _storage.delete(key: _key(_accessTokenKey));
    await _storage.delete(key: _key(_renewalTokenKey));
  }
}
