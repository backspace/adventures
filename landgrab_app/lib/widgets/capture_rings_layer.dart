import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';

/// Renders the expanding "just captured" ring at each pole whose id
/// currently appears in [captureStartedAt]. The parent is responsible
/// for the ticker that drives per-frame rebuilds and for purging
/// finished animations from the map.
///
/// Ring visual matches the site's `.landgrab-ping` — a border-only
/// circle scaling out from the pole's radius while its opacity fades
/// to zero. Radius is expressed in pixels (not metres) so the ring
/// keeps a constant visual size regardless of zoom, matching the
/// hero-page effect.
class CaptureRingsLayer extends StatelessWidget {
  final List<Pole> poles;
  final Map<String, DateTime> captureStartedAt;
  final Duration duration;
  final String? myOwnerId;
  final bool inTestPlay;

  const CaptureRingsLayer({
    super.key,
    required this.poles,
    required this.captureStartedAt,
    required this.duration,
    this.myOwnerId,
    this.inTestPlay = false,
  });

  @override
  Widget build(BuildContext context) {
    if (captureStartedAt.isEmpty) {
      return const CircleLayer(circles: []);
    }
    final now = DateTime.now();
    final circles = <CircleMarker>[];
    for (final pole in poles) {
      final start = captureStartedAt[pole.id];
      if (start == null) continue;
      final elapsedMs = now.difference(start).inMicroseconds / 1000;
      final t = (elapsedMs / duration.inMilliseconds).clamp(0.0, 1.0);
      // Site's animation is scale(1) → scale(5) with opacity 0.75 → 0.
      // We map that onto a 12 px → 60 px radius and 0.7 → 0 opacity.
      final radiusPx = 12.0 + t * 48.0;
      final opacity = (0.7 * (1 - t)).clamp(0.0, 1.0);
      final owner = pole.currentOwnerTeamId;
      final base = _baseColor(owner);
      circles.add(CircleMarker(
        point: LatLng(pole.latitude, pole.longitude),
        radius: radiusPx,
        color: Colors.transparent,
        borderColor: Color.lerp(base, Colors.white, 0.35)!
            .withValues(alpha: opacity),
        borderStrokeWidth: 2,
      ));
    }
    return CircleLayer(circles: circles);
  }

  Color _baseColor(String? ownerId) {
    if (ownerId == null) return Colors.blueGrey;
    if (inTestPlay) return Colors.green;
    if (ownerId == myOwnerId) return Colors.green;
    return Colors.red;
  }
}
