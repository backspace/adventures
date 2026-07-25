import 'dart:math' as math;

/// The endgame boundary: a capture zone centred on the wrap-party
/// location that shrinks linearly from [initialRadiusM] at [startsAt]
/// to [finalRadiusM] at [endsAt]. [radiusAt] mirrors the server's
/// interpolation exactly, so the circle players see is the boundary
/// the server enforces.
class EndgameZone {
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime endsAt;
  final double initialRadiusM;
  final double finalRadiusM;

  const EndgameZone({
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    required this.endsAt,
    required this.initialRadiusM,
    required this.finalRadiusM,
  });

  bool activeAt(DateTime now) => !now.isBefore(startsAt);

  double radiusAt(DateTime now) {
    final total = endsAt.difference(startsAt).inSeconds;
    final elapsed = now.difference(startsAt).inSeconds;
    final progress =
        total <= 0 ? 1.0 : math.min(1.0, math.max(0.0, elapsed / total));
    return initialRadiusM + (finalRadiusM - initialRadiusM) * progress;
  }

  /// Whether a point is inside the boundary at [now] — everything is
  /// "inside" before the shrink begins. Flat-earth metres with the
  /// longitude scale taken at the zone centre, matching the server's
  /// enforcement exactly.
  bool containsAt(double lat, double lng, DateTime now) {
    if (!activeAt(now)) return true;
    final r = radiusAt(now);
    const metresPerDegLat = 111000.0;
    final metresPerDegLng =
        metresPerDegLat * math.cos(latitude * math.pi / 180);
    final dx = (lng - longitude) * metresPerDegLng;
    final dy = (lat - latitude) * metresPerDegLat;
    return dx * dx + dy * dy <= r * r;
  }

  static EndgameZone? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return EndgameZone(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      startsAt: _parseUtc(json['starts_at'] as String),
      endsAt: _parseUtc(json['ends_at'] as String),
      initialRadiusM: (json['initial_radius_m'] as num).toDouble(),
      finalRadiusM: (json['final_radius_m'] as num).toDouble(),
    );
  }

  /// Server datetimes are UTC but may serialize without a zone suffix.
  static DateTime _parseUtc(String value) {
    final withZone =
        value.endsWith('Z') || value.contains('+') ? value : '${value}Z';
    return DateTime.parse(withZone);
  }
}

class LandgrabEvent {
  final String name;
  final DateTime? startTime;
  final bool started;
  final EndgameZone? endgame;
  // Newest app build the server has seen ping in, per platform (iOS/Android
  // number independently). Null until some build has pinged. The map compares
  // its own build against its platform's value for the "update available"
  // nudge.
  final int? latestBuildIos;
  final int? latestBuildAndroid;

  const LandgrabEvent({
    required this.name,
    required this.startTime,
    required this.started,
    this.endgame,
    this.latestBuildIos,
    this.latestBuildAndroid,
  });

  /// How long before the start the onboarding window opens — the instructions
  /// briefing (and anything else pre-event) becomes available this early so
  /// subjects can read along during the intro.
  static const onboardingLead = Duration(minutes: 15);

  /// Whether the onboarding window has opened: we're within [onboardingLead]
  /// of the start, or the simulation has already begun. False when no start
  /// time is scheduled yet.
  bool get onboardingStarted {
    final s = startTime;
    if (s == null) return started;
    return !DateTime.now().toUtc().isBefore(s.toUtc().subtract(onboardingLead));
  }

  factory LandgrabEvent.fromJson(Map<String, dynamic> json) => LandgrabEvent(
        name: json['name'] as String,
        startTime: json['start_time'] == null
            ? null
            : DateTime.parse(json['start_time'] as String),
        started: json['started'] as bool,
        endgame:
            EndgameZone.fromJson(json['endgame'] as Map<String, dynamic>?),
        latestBuildIos: (json['latest_build_ios'] as num?)?.toInt(),
        latestBuildAndroid: (json['latest_build_android'] as num?)?.toInt(),
      );
}
