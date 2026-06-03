import 'dart:math';

/// Great-circle distance between two lat/lon points in meters.
/// Haversine — accurate enough for the urban-scale ranges we care about
/// (sub-100m). Don't use for antipodal pairs or other edge cases that
/// don't apply here.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusM * c;
}

double _toRad(double deg) => deg * pi / 180;
