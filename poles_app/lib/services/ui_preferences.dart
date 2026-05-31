import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight persistence for non-sensitive UI preferences (toggle states,
/// last-chosen view modes, etc.). Lives separately from [UserService] which
/// holds auth state in secure storage.
class UiPreferences {
  static SharedPreferences? _cache;

  static Future<SharedPreferences> _prefs() async {
    return _cache ??= await SharedPreferences.getInstance();
  }

  /// For a screen with a list/map toggle, recall whether the user last
  /// picked the map. Defaults to false (list) the first time.
  static Future<bool> getMapPreferred(String screenKey) async {
    final p = await _prefs();
    return p.getBool('list_map_view:$screenKey') ?? false;
  }

  static Future<void> setMapPreferred(String screenKey, bool isMap) async {
    final p = await _prefs();
    await p.setBool('list_map_view:$screenKey', isMap);
  }
}
