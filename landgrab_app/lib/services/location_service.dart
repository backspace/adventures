import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:landgrab/widgets/location_rationale.dart';

/// Thrown by [LocationService.getCurrent] when location permission is
/// permanently denied. The OS won't re-prompt in this state, so the only
/// way back is the system settings — callers that catch this specifically
/// can offer an "Open Settings" affordance ([LocationService.openAppSettings]).
class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

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

  /// Whether the timestamp is recent enough that the player likely hasn't
  /// moved meaningfully since. Set generously so long form-fill sessions
  /// (puzzlet authoring) don't keep tripping it.
  bool get isFresh => DateTime.now().difference(timestamp).inMinutes < 5;

  /// Whether the GPS accuracy is good enough to record as the pole's
  /// location. Independent of staleness.
  bool get isAccurate => accuracyM <= 100;

  bool get isUsable => isFresh && isAccurate;
}

class LocationService {
  /// Returns a usable fix, or throws with a human-readable message if the
  /// device can't or won't provide one.
  ///
  /// Pass [context] to show the in-app location rationale before the OS
  /// permission dialog (the first time we'd trigger it); declining the
  /// pre-prompt counts as a denial. With no context, the OS dialog is
  /// requested directly, unchanged.
  static Future<LocationFix> getCurrent({BuildContext? context}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location services are off. Turn them on in Settings.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (context != null && context.mounted) {
        if (!await LocationRationale.show(context)) {
          throw 'Location permission was denied.';
        }
      }
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedException(
        'Location permission is off for Landgrab. Turn it on in Settings.',
      );
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

  /// Opens the OS settings page for the app, so a user whose location
  /// permission is permanently denied can re-enable it.
  static Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
