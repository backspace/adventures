import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';

/// A transient "pop" ripple emanating from a pole — a ring that expands out
/// from the pin and fades. Used to point out which pole owns a zone the player
/// just tapped: poles are all one colour now, so the pole→zone link isn't
/// otherwise obvious. The parent drives the ticker and purges finished entries
/// (same contract as [CaptureRingsLayer]); [poppedAt] maps a pole id to when
/// its pop began.
class PolePopLayer extends StatelessWidget {
  final List<Pole> poles;
  final Map<String, DateTime> poppedAt;
  final Duration duration;

  const PolePopLayer({
    super.key,
    required this.poles,
    required this.poppedAt,
    required this.duration,
  });

  // The one stake colour (see PoleDot), so the ripple reads as coming from the
  // pin rather than as a capture (which rings in the owner's colour).
  static const Color _color = Color(0xFF303F9F);

  @override
  Widget build(BuildContext context) {
    if (poppedAt.isEmpty) return const CircleLayer(circles: []);
    final now = DateTime.now();
    final byId = {for (final p in poles) p.id: p};

    final circles = <CircleMarker>[];
    for (final entry in poppedAt.entries) {
      final pole = byId[entry.key];
      if (pole == null) continue;
      final t = (now.difference(entry.value).inMicroseconds / 1000 /
              duration.inMilliseconds)
          .clamp(0.0, 1.0);
      // Ease-out: quick expansion that eases to a stop, fading as it goes.
      final e = 1 - (1 - t) * (1 - t);
      final radiusPx = 6.0 + e * 26.0;
      final opacity = (1 - t).clamp(0.0, 1.0);
      circles.add(CircleMarker(
        point: LatLng(pole.latitude, pole.longitude),
        radius: radiusPx,
        color: Colors.transparent,
        borderColor: _color.withValues(alpha: 0.85 * opacity),
        borderStrokeWidth: 3,
      ));
    }
    return CircleLayer(circles: circles);
  }
}
