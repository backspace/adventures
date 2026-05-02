import 'package:geolocator/geolocator.dart';

class LocationFix {
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime timestamp;

  LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.timestamp,
  });

  bool get isFresh => DateTime.now().difference(timestamp).inSeconds < 60;
  bool get isUsable => isFresh && accuracyM <= 100;
}

class LocationService {
  /// Returns a usable fix, or throws with a human-readable message if the
  /// device can't or won't provide one.
  static Future<LocationFix> getCurrent() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are off. Turn them on in Settings.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission is permanently denied. Allow it in Settings to capture pole locations.';
    }

    if (permission == LocationPermission.denied) {
      throw 'Location permission was denied.';
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}
