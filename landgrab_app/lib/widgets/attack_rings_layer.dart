import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';

/// A continuous red-orange pulsing ring around every pole in
/// [attackedPoleIds]. Unlike [CaptureRingsLayer], which fires once
/// per capture and expires, this layer pulses forever while a pole
/// remains in the "under attack" set — the parent decides when to
/// remove IDs (typically N minutes after the last attack signal, or
/// immediately if the pole is recaptured by anyone).
///
/// The pulse is driven by the ambient `pulsePhase` (`0..1`) which
/// the parent updates each animation tick. Radius oscillates between
/// [minRadiusPx] and [maxRadiusPx] and opacity fades in and out on
/// the same sine wave, so the ring "breathes" rather than expanding
/// and snapping back like a capture ping.
class AttackRingsLayer extends StatelessWidget {
  final List<Pole> poles;
  final Set<String> attackedPoleIds;
  final double pulsePhase;
  final double minRadiusPx;
  final double maxRadiusPx;

  const AttackRingsLayer({
    super.key,
    required this.poles,
    required this.attackedPoleIds,
    required this.pulsePhase,
    this.minRadiusPx = 18,
    this.maxRadiusPx = 34,
  });

  @override
  Widget build(BuildContext context) {
    if (attackedPoleIds.isEmpty) {
      return const CircleLayer(circles: []);
    }
    // `s` swings 0..1..0..1 as pulsePhase does 0..1.
    final s = (math.sin(pulsePhase * 2 * math.pi) + 1) / 2;
    final radius = minRadiusPx + (maxRadiusPx - minRadiusPx) * s;
    final opacity = 0.35 + 0.35 * s;

    final circles = <CircleMarker>[];
    for (final pole in poles) {
      if (!attackedPoleIds.contains(pole.id)) continue;
      circles.add(CircleMarker(
        point: LatLng(pole.latitude, pole.longitude),
        radius: radius,
        color: Colors.transparent,
        borderColor: Colors.deepOrange.withValues(alpha: opacity),
        borderStrokeWidth: 2.5,
      ));
    }
    return CircleLayer(circles: circles);
  }
}
