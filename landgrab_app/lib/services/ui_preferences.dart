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

  /// Most-recently-picked region in the region picker. Stored per-device,
  /// not synced — purely a UX nicety so the picker hoists the last choice
  /// to the top of the list.
  static Future<String?> getLastPickedRegionId() async {
    final p = await _prefs();
    return p.getString('region_picker:last_id');
  }

  static Future<void> setLastPickedRegionId(String id) async {
    final p = await _prefs();
    await p.setString('region_picker:last_id', id);
  }

  /// A map's last manually-set camera (centre + zoom), so a pan/zoom
  /// survives leaving the screen and app restarts. Stored per-device as
  /// a "lat,lng,zoom" string. Null when never set (or malformed).
  static Future<({double lat, double lng, double zoom})?> getMapCamera(
      String mapKey) async {
    final p = await _prefs();
    final raw = p.getString('map_camera:$mapKey');
    if (raw == null) return null;
    final parts = raw.split(',');
    if (parts.length != 3) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    final zoom = double.tryParse(parts[2]);
    if (lat == null || lng == null || zoom == null) return null;
    return (lat: lat, lng: lng, zoom: zoom);
  }

  static Future<void> setMapCamera(
    String mapKey, {
    required double lat,
    required double lng,
    required double zoom,
  }) async {
    final p = await _prefs();
    await p.setString('map_camera:$mapKey', '$lat,$lng,$zoom');
  }
}
