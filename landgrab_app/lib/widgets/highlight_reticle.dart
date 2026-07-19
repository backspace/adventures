import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A transient "marching ants" reticle drawn around a stake to say
/// *this one* — used when a notification's "View on map" jumps to a
/// stake. Rendered as the child of a fixed-size [Marker], so it sits
/// centred on the pole; [phase] (0..1, from the map's ambient pulse
/// ticker) rotates the dash pattern so the ants march. White dashes
/// over a dark outline keep it legible on any tile.
class HighlightReticle extends StatelessWidget {
  final double phase;
  const HighlightReticle({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _MarchingAntsPainter(phase: phase),
      ),
    );
  }
}

class _MarchingAntsPainter extends CustomPainter {
  final double phase;
  _MarchingAntsPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Even number of dashes so the ring wraps seamlessly as the phase
    // loops. Each dash sweeps `dashFraction` of its slot; the whole
    // pattern rotates by one slot over phase 0..1.
    const dashFraction = 0.55;
    final circumference = 2 * math.pi * radius;
    final count = math.max(8, (circumference / 16).round());
    final slot = 2 * math.pi / count;
    final sweep = slot * dashFraction;
    final rotate = phase * slot;

    final back = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: 0.45);
    final fore = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    for (var i = 0; i < count; i++) {
      final start = -math.pi / 2 + i * slot + rotate;
      canvas.drawArc(rect, start, sweep, false, back);
      canvas.drawArc(rect, start, sweep, false, fore);
    }
  }

  @override
  bool shouldRepaint(_MarchingAntsPainter old) => old.phase != phase;
}
