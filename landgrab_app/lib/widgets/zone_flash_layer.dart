import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// One zone flashing, with its animation [progress] (0..1). Geometry-source
/// agnostic: fed the ring + holes of whichever territory shape is in play.
class ZoneFlashShape {
  final List<LatLng> ring;
  final List<List<LatLng>> holes;
  final double progress;
  const ZoneFlashShape({
    required this.ring,
    this.holes = const [],
    required this.progress,
  });
}

/// A brief white flash over a zone — used to point out which zone belongs to a
/// pole the player just tapped (the pole→zone counterpart to [PolePopLayer]).
/// Reuses LiberatedZoneLayer's projection: projects each ring via the current
/// [MapCamera], clips a canvas to it, and washes it white at an intensity that
/// rises then falls across the flash. The parent drives the ticker and purges
/// finished entries.
class ZoneFlashLayer extends StatelessWidget {
  final List<ZoneFlashShape> shapes;
  const ZoneFlashLayer({super.key, required this.shapes});

  @override
  Widget build(BuildContext context) {
    if (shapes.isEmpty) return const SizedBox.shrink();
    final camera = MapCamera.of(context);
    return MobileLayerTransformer(
      child: CustomPaint(
        size: Size(camera.size.x, camera.size.y),
        painter: _ZoneFlashPainter(camera: camera, shapes: shapes),
      ),
    );
  }
}

class _ZoneFlashPainter extends CustomPainter {
  final MapCamera camera;
  final List<ZoneFlashShape> shapes;

  _ZoneFlashPainter({required this.camera, required this.shapes});

  Offset _project(LatLng p) => camera.getOffsetFromOrigin(p);

  ui.Path? _pathFor(ZoneFlashShape s) {
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
    for (final s in shapes) {
      // Flash: brighten then fade — sin(πt) gives 0 → 1 → 0 across the flash.
      final intensity = math.sin(s.progress.clamp(0.0, 1.0) * math.pi);
      if (intensity <= 0) continue;
      final path = _pathFor(s);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(alpha: 0.55 * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(_ZoneFlashPainter old) =>
      old.camera != camera || old.shapes != shapes;
}
