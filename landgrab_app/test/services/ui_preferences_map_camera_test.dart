import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landgrab/services/ui_preferences.dart';

// Regression tests for the map-camera NaN crash: a non-finite camera persisted
// by an older build would be restored and crash flutter_map's layout on every
// frame. Both the read and write paths must reject non-finite values.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('read rejects a non-finite persisted camera (NaN / Infinity)', () async {
    // Plant raw strings as an old build would have written them.
    final p = await SharedPreferences.getInstance();
    await p.setString('map_camera:nan', 'NaN,-97.1,14.0');
    await p.setString('map_camera:inf', '49.9,-97.1,Infinity');

    expect(await UiPreferences.getMapCamera('nan'), isNull);
    expect(await UiPreferences.getMapCamera('inf'), isNull);
  });

  test('read accepts a finite camera', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('map_camera:ok', '49.9,-97.1,14.0');

    final cam = await UiPreferences.getMapCamera('ok');
    expect(cam, isNotNull);
    expect(cam!.lat, 49.9);
    expect(cam.zoom, 14.0);
  });

  test('write never persists a non-finite camera', () async {
    await UiPreferences.setMapCamera('w1',
        lat: double.nan, lng: -97.1, zoom: 14);
    await UiPreferences.setMapCamera('w2',
        lat: 49.9, lng: -97.1, zoom: double.infinity);

    expect(await UiPreferences.getMapCamera('w1'), isNull);
    expect(await UiPreferences.getMapCamera('w2'), isNull);
  });
}
