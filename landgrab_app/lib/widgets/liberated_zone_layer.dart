import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// One liberated zone to paint: the outer ring plus any holes, in the same
/// geometry the active territory layer uses (a precomputed [TerritoryRegion]
/// ring, or a live block ring). Kept geometry-source-agnostic so the animated
/// look doesn't care which territory renderer is in play.
class LiberatedShape {
  final List<LatLng> ring;
  final List<List<LatLng>> holes;
  const LiberatedShape({required this.ring, this.holes = const []});
}

/// Tunable knobs for the liberated look, so it can be dialled in on-device
/// (see LiberatedZoneTuner) rather than guessed in a web mock. All values are
/// screen pixels except the alphas (0..1), the angle (degrees), and [speed]
/// (hatch spacings drifted per pulse cycle).
class LiberatedZoneStyle {
  final double spacing;
  final double strokeWidth;
  final double speed;
  final double angleDeg;
  final double washAlpha;
  final double lineAlpha;

  const LiberatedZoneStyle({
    this.spacing = 20,
    this.strokeWidth = 8,
    this.speed = 1,
    this.angleDeg = 45,
    this.washAlpha = 0.10,
    this.lineAlpha = 0.55,
  });

  LiberatedZoneStyle copyWith({
    double? spacing,
    double? strokeWidth,
    double? speed,
    double? angleDeg,
    double? washAlpha,
    double? lineAlpha,
  }) =>
      LiberatedZoneStyle(
        spacing: spacing ?? this.spacing,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        speed: speed ?? this.speed,
        angleDeg: angleDeg ?? this.angleDeg,
        washAlpha: washAlpha ?? this.washAlpha,
        lineAlpha: lineAlpha ?? this.lineAlpha,
      );
}

/// PROTOTYPE: a moving hatch drawn over liberated zones — freed ground that
/// belongs to no one, so it reads as *in flux* rather than as any team's
/// static claim colour (deliberately monochrome white, not a palette hue).
///
/// A flutter_map layer: it projects each shape's ring to screen space via the
/// current [MapCamera], clips a canvas to it, and paints diagonal lines that
/// drift perpendicular as [phase] (the map's ambient 0..1 pulse) advances.
/// Only liberated blocks animate — the big static territory fill stays a plain
/// PolygonLayer beneath this — so the per-frame cost is a handful of small
/// clipped regions, not the whole map.
class LiberatedZoneLayer extends StatelessWidget {
  final List<LiberatedShape> shapes;
  final double phase;
  final LiberatedZoneStyle style;

  const LiberatedZoneLayer({
    super.key,
    required this.shapes,
    required this.phase,
    this.style = const LiberatedZoneStyle(),
  });

  @override
  Widget build(BuildContext context) {
    if (shapes.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    // MobileLayerTransformer puts the canvas in the map's origin space and
    // applies the pan/zoom transform for us — the same wrapper flutter_map's
    // own PolygonLayer uses. Ring vertices are projected with
    // getOffsetFromOrigin to match. (A bare Positioned/CustomPaint here is
    // NOT a direct Stack child — flutter_map wraps each layer — which throws
    // "Incorrect use of ParentDataWidget".)
    return MobileLayerTransformer(
      child: CustomPaint(
        size: Size(camera.size.x, camera.size.y),
        painter: _HatchPainter(
          camera: camera,
          shapes: shapes,
          phase: phase,
          style: style,
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  final MapCamera camera;
  final List<LiberatedShape> shapes;
  final double phase;
  final LiberatedZoneStyle style;

  _HatchPainter({
    required this.camera,
    required this.shapes,
    required this.phase,
    required this.style,
  });

  // Origin-space projection (not screen space): MobileLayerTransformer applies
  // the map transform on top, matching flutter_map's own PolygonPainter.
  Offset _project(LatLng p) => camera.getOffsetFromOrigin(p);

  ui.Path? _pathFor(LiberatedShape shape) {
    if (shape.ring.length < 3) return null;
    final path = ui.Path()..fillType = PathFillType.evenOdd;
    _addRing(path, shape.ring);
    for (final hole in shape.holes) {
      if (hole.length >= 3) _addRing(path, hole);
    }
    return path;
  }

  void _addRing(ui.Path path, List<LatLng> ring) {
    final first = _project(ring.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < ring.length; i++) {
      final o = _project(ring[i]);
      path.lineTo(o.dx, o.dy);
    }
    path.close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final theta = style.angleDeg * math.pi / 180;
    final dir = Offset(math.cos(theta), math.sin(theta));
    final perp = Offset(-math.sin(theta), math.cos(theta));
    // Drift one spacing per cycle × speed, wrapped so the pattern loops
    // seamlessly (no jump when phase rolls 1 → 0).
    final shift = ((phase * style.speed) % 1.0) * style.spacing;

    final wash = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: style.washAlpha);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: style.lineAlpha);
    // A dark keyline under the white hatch keeps it legible over pale tiles.
    final lineShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth + 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.black.withValues(alpha: style.lineAlpha * 0.4);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.8);

    for (final shape in shapes) {
      final path = _pathFor(shape);
      if (path == null) continue;
      final bounds = path.getBounds();
      if (bounds.isEmpty) continue;

      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, wash);

      // Lines are the loci where (point · perp) = d, for d stepped by spacing
      // across the clip's diagonal; each is drawn long enough to span it.
      final diag = bounds.longestSide * 1.5;
      final centre = bounds.center;
      for (var d = -diag; d <= diag; d += style.spacing) {
        final dd = d + shift;
        final mid = centre + perp * dd;
        final a = mid - dir * diag;
        final b = mid + dir * diag;
        canvas.drawLine(a, b, lineShadow);
        canvas.drawLine(a, b, line);
      }
      canvas.restore();

      // Outline on top of the clip, so the freed zone has a crisp edge.
      canvas.drawPath(path, outline);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) =>
      old.phase != phase ||
      old.camera != camera ||
      old.shapes != shapes ||
      old.style != style;
}
