import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';

/// Draws a coloured territory zone around each *captured* pole.
///
/// Cells are computed via radius-capped Voronoi over ALL poles (not
/// just captured ones), so cell shapes are stable — capturing a pole
/// changes its cell's fill colour but never the layout of neighbouring
/// cells. Naturally handles both extremes:
///
///   * Clustered poles → cells shrink to slivers as adjacent
///     bisectors cut into the disc.
///   * Isolated poles → disc caps at [radiusMeters] rather than
///     stretching to the viewport edge.
///
/// The math runs in a local metric projection (metres east/north of
/// the pole set's centroid) so distances behave like ordinary
/// Euclidean distances; results are un-projected back to LatLng for
/// [PolygonLayer]. At the ~city-block scale this app cares about, the
/// projection distortion is imperceptible.
///
/// Complexity is O(N²) polygon clips; for N in the tens (event
/// scale) this runs in single-digit milliseconds and only re-runs
/// when the pole set itself changes.
class TerritoryLayer extends StatelessWidget {
  final List<Pole> poles;
  final String? myOwnerId;
  final bool inTestPlay;
  final double radiusMeters;

  const TerritoryLayer({
    super.key,
    required this.poles,
    this.myOwnerId,
    this.inTestPlay = false,
    this.radiusMeters = 200,
  });

  @override
  Widget build(BuildContext context) {
    final cells = _computeCells();
    final polygons = <Polygon>[];
    for (var i = 0; i < poles.length; i++) {
      final pole = poles[i];
      final owner = pole.currentOwnerTeamId;
      if (owner == null) continue;
      final cell = cells[i];
      if (cell == null || cell.length < 3) continue;
      polygons.add(Polygon(
        points: cell,
        color: _colorFor(owner).withValues(alpha: 0.28),
        borderColor: _colorFor(owner).withValues(alpha: 0.7),
        borderStrokeWidth: 1.5,
        isFilled: true,
      ));
    }
    return PolygonLayer(polygons: polygons);
  }

  Color _colorFor(String ownerId) {
    // Match `_pinColor` in home_route: in test-play any owner is you,
    // so the whole territory reads as "yours". In real play, match
    // vs. rival by team id.
    if (inTestPlay) return Colors.green;
    if (ownerId == myOwnerId) return Colors.green;
    return Colors.red;
  }

  // ─── Geometry ────────────────────────────────────────────────────

  /// Returns cell polygons indexed by pole position in [poles]. Only
  /// filled for poles that end up with a non-degenerate cell (>= 3
  /// vertices after clipping); a pole tightly surrounded by others
  /// may end up empty and is simply omitted.
  Map<int, List<LatLng>> _computeCells() {
    final result = <int, List<LatLng>>{};
    if (poles.isEmpty) return result;

    // Local metric projection anchored on the pole-set centroid.
    // Using the *centroid's* latitude for the longitude scale keeps
    // the ellipse ≈ isotropic across the visible poles instead of
    // biasing north or south.
    var sumLat = 0.0;
    var sumLon = 0.0;
    for (final p in poles) {
      sumLat += p.latitude;
      sumLon += p.longitude;
    }
    final centroidLat = sumLat / poles.length;
    final centroidLon = sumLon / poles.length;
    const metresPerDegLat = 111000.0;
    final metresPerDegLon =
        111000.0 * math.cos(centroidLat * math.pi / 180);

    _Point project(double lat, double lon) => (
          x: (lon - centroidLon) * metresPerDegLon,
          y: (lat - centroidLat) * metresPerDegLat,
        );
    LatLng unproject(_Point p) => LatLng(
          centroidLat + p.y / metresPerDegLat,
          centroidLon + p.x / metresPerDegLon,
        );

    final projected = [
      for (final p in poles) project(p.latitude, p.longitude),
    ];

    // Twice the radius is the maximum useful bisector distance —
    // beyond that the bisector doesn't cross the disc.
    final maxBisectorDistance = 2 * radiusMeters;

    for (var i = 0; i < poles.length; i++) {
      final centre = projected[i];
      var cell = _discPolygon(centre, radiusMeters, sides: 32);

      for (var j = 0; j < poles.length; j++) {
        if (i == j) continue;
        final other = projected[j];
        final dx = other.x - centre.x;
        final dy = other.y - centre.y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > maxBisectorDistance) continue;
        cell = _clipToHalfPlane(cell, centre, other);
        if (cell.isEmpty) break;
      }

      if (cell.length >= 3) {
        result[i] = [for (final p in cell) unproject(p)];
      }
    }

    return result;
  }

  /// Regular N-gon approximating a disc — the starting polygon for
  /// each Voronoi cell before neighbour bisectors clip it in.
  List<_Point> _discPolygon(_Point centre, double radius,
      {required int sides}) {
    return [
      for (var k = 0; k < sides; k++)
        (
          x: centre.x + radius * math.cos(2 * math.pi * k / sides),
          y: centre.y + radius * math.sin(2 * math.pi * k / sides),
        )
    ];
  }

  /// Sutherland–Hodgman clip: keep the portion of [polygon] on the
  /// [inside] side (closer to [inside] than to [outside]) of the
  /// perpendicular bisector between them.
  List<_Point> _clipToHalfPlane(
      List<_Point> polygon, _Point inside, _Point outside) {
    if (polygon.isEmpty) return polygon;

    // Perpendicular bisector: line through midpoint m, normal n
    // pointing from `inside` toward `outside`. A vertex is "kept"
    // when (v - m) · n <= 0.
    final mx = (inside.x + outside.x) / 2;
    final my = (inside.y + outside.y) / 2;
    final nx = outside.x - inside.x;
    final ny = outside.y - inside.y;

    double signedDist(_Point v) => (v.x - mx) * nx + (v.y - my) * ny;

    _Point intersect(_Point a, _Point b) {
      final da = signedDist(a);
      final db = signedDist(b);
      final t = da / (da - db);
      return (x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y));
    }

    final out = <_Point>[];
    for (var i = 0; i < polygon.length; i++) {
      final current = polygon[i];
      final previous = polygon[(i - 1 + polygon.length) % polygon.length];
      final currentIn = signedDist(current) <= 0;
      final previousIn = signedDist(previous) <= 0;
      if (currentIn) {
        if (!previousIn) out.add(intersect(previous, current));
        out.add(current);
      } else if (previousIn) {
        out.add(intersect(previous, current));
      }
    }
    return out;
  }
}

typedef _Point = ({double x, double y});
