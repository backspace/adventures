import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/widgets/team_style.dart';

/// PROTOTYPE preview switch. Real teams only get a non-solid pattern once the
/// roster passes the 12-colour palette (the 13th team onward), so on a small
/// test roster you'd see no texture at all. Flip this to `true` to force a
/// varied pattern onto EVERY owned zone so the look can be judged with only a
/// few teams. MUST be `false` in production — otherwise band-0 teams (which
/// should read as a plain colour) get textured too.
const bool kPreviewAllZonePatterns = false;

/// One owned zone to texture with its team's pattern. Carries the resolved
/// [pattern] + [color] rather than a colour index, so the caller owns the
/// team→style mapping (and any preview override) and the painter just draws.
class TerritoryPatternShape {
  final List<LatLng> ring;
  final List<List<LatLng>> holes;
  final TeamPattern pattern;
  final Color color;

  const TerritoryPatternShape({
    required this.ring,
    this.holes = const [],
    required this.pattern,
    required this.color,
  });
}

/// PROTOTYPE: paints each team's [TeamStyle] pattern INTO its territory fill as
/// a hatch, so two teams that share a colour (rosters past the 12-colour
/// palette) still read apart by texture — not only by the glyph on their pole
/// dot. Solid-pattern teams (the first 12) are left as a plain colour fill.
///
/// Reuses LiberatedZoneLayer's projection technique: a flutter_map layer that
/// projects each ring via the current [MapCamera], clips a canvas to it, and
/// strokes the pattern in the team's own (darkened) ink. Static — a claim isn't
/// "in flux" like freed ground — so there's no per-frame animation cost, and
/// with ≤12 teams the shape list is empty and this renders nothing at all.
class TerritoryPatternLayer extends StatelessWidget {
  final List<TerritoryPatternShape> shapes;

  /// Screen-space gap between hatch lines and their stroke width.
  final double spacing;
  final double strokeWidth;

  const TerritoryPatternLayer({
    super.key,
    required this.shapes,
    this.spacing = 11,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    if (shapes.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    // MobileLayerTransformer puts the canvas in the map's origin space and
    // applies the pan/zoom transform, matching flutter_map's own PolygonLayer;
    // ring vertices project with getOffsetFromOrigin to match. (Same wrapper
    // LiberatedZoneLayer uses — a bare CustomPaint child throws "Incorrect use
    // of ParentDataWidget".)
    return MobileLayerTransformer(
      child: CustomPaint(
        size: Size(camera.size.x, camera.size.y),
        painter: _TerritoryPatternPainter(
          camera: camera,
          shapes: shapes,
          spacing: spacing,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _TerritoryPatternPainter extends CustomPainter {
  final MapCamera camera;
  final List<TerritoryPatternShape> shapes;
  final double spacing;
  final double strokeWidth;

  _TerritoryPatternPainter({
    required this.camera,
    required this.shapes,
    required this.spacing,
    required this.strokeWidth,
  });

  Offset _project(LatLng p) => camera.getOffsetFromOrigin(p);

  ui.Path? _pathFor(TerritoryPatternShape s) {
    if (s.ring.length < 3) return null;
    final path = ui.Path()..fillType = PathFillType.evenOdd;
    _addRing(path, s.ring);
    for (final hole in s.holes) {
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
    for (final shape in shapes) {
      if (shape.pattern == TeamPattern.solid) continue;

      final path = _pathFor(shape);
      if (path == null) continue;
      final bounds = path.getBounds();
      if (bounds.isEmpty) continue;

      // Texture in a darkened team ink so it stays within the zone's own hue;
      // the flat colour fill still shows between the lines/dots/xes. Kept faint
      // so a dense map reads as a subtle texture, not noise.
      final ink =
          Color.lerp(shape.color, Colors.black, 0.35)!.withValues(alpha: 0.3);

      canvas.save();
      canvas.clipPath(path);

      switch (shape.pattern) {
        case TeamPattern.dots:
          final dot = Paint()
            ..style = PaintingStyle.fill
            ..color = ink;
          final step = spacing * 1.5;
          final dr = strokeWidth * 0.95;
          for (var x = bounds.left; x <= bounds.right; x += step) {
            for (var y = bounds.top; y <= bounds.bottom; y += step) {
              canvas.drawCircle(Offset(x, y), dr, dot);
            }
          }
        case TeamPattern.xes:
          final stroke = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = ink;
          final step = spacing * 1.7;
          final a = strokeWidth * 1.15;
          for (var x = bounds.left; x <= bounds.right; x += step) {
            for (var y = bounds.top; y <= bounds.bottom; y += step) {
              canvas.drawLine(
                  Offset(x - a, y - a), Offset(x + a, y + a), stroke);
              canvas.drawLine(
                  Offset(x - a, y + a), Offset(x + a, y - a), stroke);
            }
          }
        default:
          // hatch / backHatch — one diagonal direction.
          final line = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..color = ink;
          final diag = bounds.longestSide * 1.5;
          final centre = bounds.center;
          final deg = shape.pattern == TeamPattern.hatch ? 45.0 : -45.0;
          final theta = deg * math.pi / 180;
          final dir = Offset(math.cos(theta), math.sin(theta));
          final perp = Offset(-math.sin(theta), math.cos(theta));
          for (var d = -diag; d <= diag; d += spacing) {
            final mid = centre + perp * d;
            canvas.drawLine(mid - dir * diag, mid + dir * diag, line);
          }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TerritoryPatternPainter old) =>
      old.camera != camera ||
      old.shapes != shapes ||
      old.spacing != spacing ||
      old.strokeWidth != strokeWidth;
}
