import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';
import 'package:landgrab/widgets/team_style.dart';

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
  // team_id → colour index (from the server's stable per-team ordinal), so
  // each team's territory gets its own colour. Includes just-deposed teams
  // (for the capture animation's under-fill).
  final Map<String, int> colorIndexByTeam;
  final double radiusMeters;
  final Map<String, DateTime> captureStartedAt;

  /// Team that held each pole before its current capture animation —
  /// painted under the expanding disc so a takeover sweeps the new
  /// colour over the old instead of wiping to empty first.
  final Map<String, String?> captureFromOwner;
  final Duration captureAnimationDuration;

  const TerritoryLayer({
    super.key,
    required this.poles,
    this.myOwnerId,
    this.colorIndexByTeam = const {},
    this.radiusMeters = 100,
    this.captureStartedAt = const {},
    this.captureFromOwner = const {},
    this.captureAnimationDuration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final cells = _computeCells();
    final now = DateTime.now();
    // Rivals first, mine last: PolygonLayer paints in list order, so
    // drawing my cells on top keeps their outline from being painted over
    // by a neighbouring rival cell (why it showed on some edges but not
    // others).
    final rivals = <Polygon>[];
    final mine = <Polygon>[];
    for (var i = 0; i < poles.length; i++) {
      final pole = poles[i];
      final owner = pole.currentOwnerTeamId;
      if (owner == null) continue;
      var cell = cells[i];
      if (cell == null || cell.length < 3) continue;

      // If this pole is currently animating a fresh capture, clip its
      // cell to a growing disc so the fill visibly flows outward from
      // the pole's position rather than snapping in. Progress in
      // [0, 1] maps to disc radius in [0, radiusMeters] — matches the
      // ping ring's timing, so the two effects read as one gesture.
      final startedAt = captureStartedAt[pole.id];
      if (startedAt != null) {
        final elapsedMs = now.difference(startedAt).inMicroseconds / 1000;
        final t = (elapsedMs / captureAnimationDuration.inMilliseconds)
            .clamp(0.0, 1.0);
        if (t < 1.0) {
          // Takeover: the deposed team's fill stays put underneath
          // while the disc sweeps the new colour over it. Without
          // this the old fill vanished at frame one and the cell
          // refilled from empty.
          final previousOwner = captureFromOwner[pole.id];
          if (previousOwner != null) {
            rivals.add(_territoryPolygon(cell, previousOwner));
          }
          cell = _clipToExpandingDisc(cell, pole, t);
          if (cell == null || cell.length < 3) continue;
        }
      }

      if (owner == myOwnerId) {
        mine.addAll(_myPolygons(cell, owner));
      } else {
        rivals.add(_territoryPolygon(cell, owner));
      }
    }
    return PolygonLayer(polygons: [...rivals, ...mine]);
  }

  Polygon _territoryPolygon(List<LatLng> points, String ownerId) {
    final color = _colorFor(ownerId);
    return Polygon(
      points: points,
      color: color.withValues(alpha: 0.26),
      borderColor: color.withValues(alpha: 0.7),
      borderStrokeWidth: 1.5,
      isFilled: true,
    );
  }

  /// My own territory: a slightly stronger fill plus a "cased" outline —
  /// a dark halo under a white core — so the boundary stays legible over
  /// both the pale basemap and rival fills. (Plain white vanished where a
  /// zone met the map instead of a rival colour.) Returned as separate
  /// fill + halo + core polygons so the outline paints cleanly on top.
  List<Polygon> _myPolygons(List<LatLng> points, String ownerId) {
    final color = _colorFor(ownerId);
    return [
      Polygon(
        points: points,
        color: color.withValues(alpha: 0.40),
        borderStrokeWidth: 0,
        isFilled: true,
      ),
      Polygon(
        points: points,
        isFilled: false,
        borderStrokeWidth: 4.5,
        borderColor: Colors.black.withValues(alpha: 0.55),
      ),
      Polygon(
        points: points,
        isFilled: false,
        borderStrokeWidth: 2.5,
        borderColor: Colors.white,
      ),
    ];
  }

  /// Re-clip the already-computed cell (in LatLng) against a disc
  /// centred on the pole with radius `progress * radiusMeters`. Runs
  /// the same metric projection + Sutherland-Hodgman as the cell
  /// computation itself, so the geometry stays consistent.
  List<LatLng>? _clipToExpandingDisc(
    List<LatLng> cell,
    Pole pole,
    double progress,
  ) {
    if (cell.isEmpty) return cell;
    const metresPerDegLat = 111000.0;
    // Local anchor at the pole itself — every projection is relative
    // to it so the disc math is trivially centred at origin.
    final cosLat = math.cos(pole.latitude * math.pi / 180);
    final metresPerDegLon = 111000.0 * cosLat;

    List<_Point> polygonInMetres = [
      for (final p in cell)
        (
          x: (p.longitude - pole.longitude) * metresPerDegLon,
          y: (p.latitude - pole.latitude) * metresPerDegLat,
        ),
    ];

    // Approximate the disc as a 24-gon and clip against each edge.
    const sides = 24;
    final r = progress * radiusMeters;
    for (var k = 0; k < sides; k++) {
      final theta1 = 2 * math.pi * k / sides;
      final theta2 = 2 * math.pi * (k + 1) / sides;
      final ax = r * math.cos(theta1);
      final ay = r * math.sin(theta1);
      final bx = r * math.cos(theta2);
      final by = r * math.sin(theta2);
      polygonInMetres = _clipToInnerSide(polygonInMetres, ax, ay, bx, by);
      if (polygonInMetres.isEmpty) return null;
    }

    return [
      for (final p in polygonInMetres)
        LatLng(
          pole.latitude + p.y / metresPerDegLat,
          pole.longitude + p.x / metresPerDegLon,
        )
    ];
  }

  /// Clip [polygon] to the half-plane on the "inside" (origin side)
  /// of the line through (ax, ay)→(bx, by). Used to build a disc
  /// intersection from consecutive edges of the disc's polygonal
  /// approximation.
  List<_Point> _clipToInnerSide(
      List<_Point> polygon, double ax, double ay, double bx, double by) {
    // Normal pointing away from origin (outside): rotate edge by 90°.
    final ex = bx - ax;
    final ey = by - ay;
    final nx = ey;
    final ny = -ex;
    // Point is inside if (v - a) · n <= 0.
    double signedDist(_Point v) => (v.x - ax) * nx + (v.y - ay) * ny;
    _Point intersect(_Point p, _Point q) {
      final dp = signedDist(p);
      final dq = signedDist(q);
      final t = dp / (dp - dq);
      return (x: p.x + t * (q.x - p.x), y: p.y + t * (q.y - p.y));
    }
    if (polygon.isEmpty) return polygon;
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

  Color _colorFor(String ownerId) {
    final index = colorIndexByTeam[ownerId];
    // Unknown team (colour index not seen yet) — neutral rather than a crash.
    if (index == null) return Colors.blueGrey;
    return TeamStyle.forIndex(index).color;
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
