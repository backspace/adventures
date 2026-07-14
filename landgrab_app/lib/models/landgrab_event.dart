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

  const LandgrabEvent({
    required this.name,
    required this.startTime,
    required this.started,
    this.endgame,
  });

  factory LandgrabEvent.fromJson(Map<String, dynamic> json) => LandgrabEvent(
        name: json['name'] as String,
        startTime: json['start_time'] == null
            ? null
            : DateTime.parse(json['start_time'] as String),
        started: json['started'] as bool,
        endgame:
            EndgameZone.fromJson(json['endgame'] as Map<String, dynamic>?),
      );
}
