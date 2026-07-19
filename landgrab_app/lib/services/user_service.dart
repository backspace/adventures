import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Display-facing summary of a saved account (dev account-switcher).
/// Tokens stay inside [UserService]; this only carries what the picker
/// shows.
class SavedAccount {
  final String id;
  final String email;
  final String? name;
  final List<String> roles;
  final String? teamName;

  SavedAccount({
    required this.id,
    required this.email,
    this.name,
    this.roles = const [],
    this.teamName,
  });
}

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
  // The build flavor that set the override, so a stale override from a
  // different flavor (e.g. a staging switch carried into a production
  // install) can be dropped on launch. See EnvService.initialize.
  static const String _apiRootOverrideFlavorKey = 'api_root_override_flavor';

  // Per-env key suffixes — actual storage key is `${suffix}:${apiRoot}`
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _teamIdKey = 'team_id';
  static const String _teamNameKey = 'team_name';
  static const String _teamColorIndexKey = 'team_color_index';
  static const String _rolesKey = 'roles';
  static const String _accessTokenKey = 'access_token';
  static const String _renewalTokenKey = 'renewal_token';
  // A JSON list of full session bundles for this env — the saved
  // accounts the dev switcher lists.
  static const String _savedAccountsKey = 'saved_accounts';

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
    int? teamColorIndex,
    List<String>? roles,
  }) async {
    await _storage.write(key: _key(_userIdKey), value: userId);
    await _storage.write(key: _key(_userEmailKey), value: email);
    if (name != null) await _storage.write(key: _key(_userNameKey), value: name);
    // Team is write-or-delete, not write-if-present: the sole caller
    // (LandgrabApi.loadAndStoreMe) always passes the full /me snapshot,
    // so a null here means "no team now" and must clear any previously
    // stored team — otherwise a user removed from their team keeps
    // showing the stale one (and the no-team guard never triggers).
    if (teamId != null) {
      await _storage.write(key: _key(_teamIdKey), value: teamId);
    } else {
      await _storage.delete(key: _key(_teamIdKey));
    }
    if (teamName != null) {
      await _storage.write(key: _key(_teamNameKey), value: teamName);
    } else {
      await _storage.delete(key: _key(_teamNameKey));
    }
    // Same write-or-delete discipline as the team fields: a null in the /me
    // snapshot must clear a stale colour, not leave the old one behind.
    if (teamColorIndex != null) {
      await _storage.write(
          key: _key(_teamColorIndexKey), value: teamColorIndex.toString());
    } else {
      await _storage.delete(key: _key(_teamColorIndexKey));
    }
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
  static Future<int?> getTeamColorIndex() async =>
      int.tryParse(await _storage.read(key: _key(_teamColorIndexKey)) ?? '');
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

  /// The build flavor that set the current override. Null when there's no
  /// override, or when it was set by a build predating this bookkeeping.
  static Future<String?> getApiRootOverrideFlavor() =>
      _storage.read(key: _apiRootOverrideFlavorKey);

  static Future<void> setApiRootOverride(String? value, {String? flavor}) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _apiRootOverrideKey);
      await _storage.delete(key: _apiRootOverrideFlavorKey);
    } else {
      await _storage.write(key: _apiRootOverrideKey, value: value);
      if (flavor != null) {
        await _storage.write(key: _apiRootOverrideFlavorKey, value: flavor);
      }
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
    await _storage.delete(key: _key(_teamColorIndexKey));
    await _storage.delete(key: _key(_rolesKey));
    await _storage.delete(key: _key(_accessTokenKey));
    await _storage.delete(key: _key(_renewalTokenKey));
  }

  // ──────── Saved accounts (dev account-switcher) ────────────────────
  //
  // A me-only affordance behind the env-switch unlock. Accounts are
  // stored per env (the key is namespaced by apiRoot like everything
  // else), so each env has its own list.

  static Future<void> _writeField(String suffix, String? value) async {
    if (value == null) {
      await _storage.delete(key: _key(suffix));
    } else {
      await _storage.write(key: _key(suffix), value: value);
    }
  }

  static Future<List<Map<String, dynamic>>> _readAccounts() async {
    final raw = await _storage.read(key: _key(_savedAccountsKey));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _writeAccounts(List<Map<String, dynamic>> list) =>
      _storage.write(key: _key(_savedAccountsKey), value: jsonEncode(list));

  /// Snapshot the currently-active session into this env's saved-accounts
  /// list (deduped by user id). Called after each login so accounts are
  /// auto-remembered, and before switching away so refreshed tokens are
  /// captured. No-op if there's no complete session.
  static Future<void> rememberCurrentAccount() async {
    final id = await getUserId();
    final email = await getUserEmail();
    final access = await getAccessToken();
    if (id == null || email == null || access == null) return;

    final entry = {
      'id': id,
      'email': email,
      'name': await getUserName(),
      'teamId': await getTeamId(),
      'teamName': await getTeamName(),
      'roles': await getRoles(),
      'accessToken': access,
      'renewalToken': await getRenewalToken(),
    };
    final list = await _readAccounts();
    list.removeWhere((a) => a['id'] == id);
    list.add(entry);
    await _writeAccounts(list);
  }

  static Future<List<SavedAccount>> getSavedAccounts() async {
    final list = await _readAccounts();
    return list
        .map((a) => SavedAccount(
              id: a['id'] as String,
              email: a['email'] as String,
              name: a['name'] as String?,
              roles: ((a['roles'] as List?) ?? const []).cast<String>(),
              teamName: a['teamName'] as String?,
            ))
        .toList();
  }

  /// Make the saved account with [id] the active session for this env.
  /// The outgoing account is re-remembered first so its (possibly
  /// refreshed) tokens aren't lost. The caller reboots afterwards.
  static Future<void> switchToAccount(String id) async {
    await rememberCurrentAccount();

    final list = await _readAccounts();
    Map<String, dynamic>? target;
    for (final a in list) {
      if (a['id'] == id) {
        target = a;
        break;
      }
    }
    if (target == null) return;

    final roles = ((target['roles'] as List?) ?? const []).cast<String>();
    await _writeField(_userIdKey, target['id'] as String?);
    await _writeField(_userEmailKey, target['email'] as String?);
    await _writeField(_userNameKey, target['name'] as String?);
    await _writeField(_teamIdKey, target['teamId'] as String?);
    await _writeField(_teamNameKey, target['teamName'] as String?);
    await _writeField(_rolesKey, roles.isEmpty ? null : roles.join(','));
    await _writeField(_accessTokenKey, target['accessToken'] as String?);
    await _writeField(_renewalTokenKey, target['renewalToken'] as String?);
  }

  static Future<void> removeSavedAccount(String id) async {
    final list = await _readAccounts();
    list.removeWhere((a) => a['id'] == id);
    await _writeAccounts(list);
  }
}
