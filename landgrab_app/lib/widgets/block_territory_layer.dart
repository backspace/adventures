import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';
import 'package:landgrab/services/block_territory_service.dart';
import 'package:landgrab/widgets/team_style.dart';

/// EXPERIMENT: street-aware territory. Colours pre-computed city blocks by the
/// team that owns them, so a zone follows the grid instead of the abstract
/// Voronoi cell ([TerritoryLayer]). Drop-in alternative — the map picks this
/// only when a blocks asset is present ([BlockTerritoryService]); otherwise it
/// uses the Voronoi layer.
///
/// Design + rationale:
/// ~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md
///
/// Behaviour:
///  * Each pole ties to the block it stands in, else its nearest block within
///    [maxAssignMeters].
///  * One owner in a block → whole block; two+ owned poles sharing a block →
///    split along their bisector (no discs).
///  * (Step 1) If [puzzletPointsByPole] is supplied, a pole's territory also
///    extends into an *empty* block that contains one of its puzzlets, as long
///    as that block stays contiguous with the pole's existing territory — so
///    zones reflect where the puzzlets are, without islands.
///  * Every remaining block inside the seeds' convex hull joins its nearest
///    pole (a block-level Voronoi, hull-clipped), so captured zones grow toward
///    each other and leave no zone-less gaps within the play area.
class BlockTerritoryLayer extends StatelessWidget {
  final List<TerritoryBlock> blocks;
  final List<Pole> poles;
  final String? myOwnerId;
  final Map<String, int> colorIndexByTeam;

  /// pole id → its puzzlets' locations. Null disables puzzlet extension.
  final Map<String, List<LatLng>>? puzzletPointsByPole;

  /// A pole further than this from every block stays without territory.
  final double maxAssignMeters;

  /// My team has joined the subversion: drop the white cased outline on my own
  /// zones (see [PrecomputedTerritoryLayer]).
  final bool joinedSubversion;

  const BlockTerritoryLayer({
    super.key,
    required this.blocks,
    required this.poles,
    this.myOwnerId,
    this.colorIndexByTeam = const {},
    this.puzzletPointsByPole,
    this.maxAssignMeters = 300,
    this.joinedSubversion = false,
  });

  @override
  Widget build(BuildContext context) {
    final poleBlock = _assignmentFor(blocks, poles, maxAssignMeters);

    // Blocks that are some pole's home (owned or not) — not eligible for
    // puzzlet extension.
    final occupied = <int>{};
    for (final b in poleBlock) {
      if (b != null) occupied.add(b);
    }

    // Owned poles per home block (for the single/split render).
    final ownedByBlock = <int, List<int>>{};
    for (var p = 0; p < poles.length; p++) {
      if (poles[p].currentOwnerTeamId == null) continue;
      final b = poleBlock[p];
      if (b == null) continue;
      (ownedByBlock[b] ??= []).add(p);
    }

    // Puzzlet-driven extension: empty block → claiming pole index.
    final extended = _extend(poleBlock, occupied);

    final rivals = <Polygon>[];
    final mine = <Polygon>[];

    ownedByBlock.forEach((b, owners) {
      final ring = blocks[b].ring;
      if (owners.length == 1) {
        _emit(ring, poles[owners.first].currentOwnerTeamId!, rivals, mine);
      } else {
        for (final p in owners) {
          final piece = _clipToOwner(ring, p, owners);
          if (piece != null) {
            _emit(piece, poles[p].currentOwnerTeamId!, rivals, mine);
          }
        }
      }
    });

    extended.forEach((b, p) {
      _emit(blocks[b].ring, poles[p].currentOwnerTeamId!, rivals, mine);
    });

    // Fill: every remaining block inside the seeds' convex hull joins its
    // nearest pole, so captured zones grow toward each other and leave no
    // zone-less gaps within the play area (a block-level Voronoi, clipped to
    // the hull). A gap whose nearest pole isn't captured stays genuinely
    // blank — that's an unclaimed region, not a hole.
    final fill = _fillFor(blocks, poles, _seeds(), occupied);
    fill.forEach((b, p) {
      if (extended.containsKey(b)) return; // puzzlet extension already owns it
      final owner = poles[p].currentOwnerTeamId;
      if (owner == null) return;
      _emit(blocks[b].ring, owner, rivals, mine);
    });

    return PolygonLayer(polygons: [...rivals, ...mine]);
  }

  List<LatLng> _seeds() {
    final s = [for (final p in poles) LatLng(p.latitude, p.longitude)];
    final pts = puzzletPointsByPole;
    if (pts != null) {
      for (final list in pts.values) {
        s.addAll(list);
      }
    }
    return s;
  }

  void _emit(
    List<LatLng> ring,
    String owner,
    List<Polygon> rivals,
    List<Polygon> mine,
  ) {
    if (ring.length < 3) return;
    if (owner == myOwnerId) {
      mine.addAll(_myPolygons(ring, owner));
    } else {
      rivals.add(_fill(ring, owner));
    }
  }

  // ── Puzzlet extension (contiguity-constrained) ──

  /// Grow each owned pole's territory into empty blocks holding its puzzlets,
  /// but only where they stay connected to its existing blocks. Returns
  /// { block index → claiming pole index }.
  Map<int, int> _extend(List<int?> poleBlock, Set<int> occupied) {
    final pts = puzzletPointsByPole;
    if (pts == null || pts.isEmpty) return const {};

    // Empty blocks each pole's puzzlets fall in (geometry-only, cached).
    final candidates = _candidatesFor(blocks, poles, pts, occupied);
    if (candidates.isEmpty) return const {};

    final adj = _adjacencyFor(blocks);
    final claimed = <int, int>{};

    // Deterministic order so a block reachable by two poles goes to the
    // lower-indexed one.
    final order = candidates.keys.toList()..sort();
    for (final p in order) {
      if (poles[p].currentOwnerTeamId == null) continue; // only owned extend
      final home = poleBlock[p];
      if (home == null) continue; // no seed → can't stay contiguous
      final region = <int>{home};
      final want = candidates[p]!;
      var grew = true;
      while (grew) {
        grew = false;
        for (final b in want) {
          if (region.contains(b) || claimed.containsKey(b)) continue;
          if (adj[b].any(region.contains)) {
            region.add(b);
            claimed[b] = p;
            grew = true;
          }
        }
      }
    }
    return claimed;
  }

  // ── Styling (mirrors TerritoryLayer so the two read identically) ──

  Color _colorFor(String ownerId) {
    final index = colorIndexByTeam[ownerId];
    if (index == null) return Colors.blueGrey;
    return TeamStyle.forIndex(index).color;
  }

  Polygon _fill(List<LatLng> points, String ownerId, {double alpha = 0.26}) {
    final color = _colorFor(ownerId);
    return Polygon(
      points: points,
      color: color.withValues(alpha: alpha),
      borderColor: color.withValues(alpha: 0.7),
      borderStrokeWidth: 1.5,
      isFilled: true,
    );
  }

  List<Polygon> _myPolygons(List<LatLng> points, String ownerId) {
    // Joined the subversion: stronger own-zone fill, but no white cased outline.
    if (joinedSubversion) return [_fill(points, ownerId, alpha: 0.40)];
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

  // ── Block splitting: pole p's share of a block shared with [owners] ──

  List<LatLng>? _clipToOwner(List<LatLng> ring, int p, List<int> owners) {
    final anchor = ring.first;
    final perDegLat = 111000.0;
    final perDegLon = 111000.0 * math.cos(anchor.latitude * math.pi / 180);

    _Pt toM(double lat, double lng) => (
          x: (lng - anchor.longitude) * perDegLon,
          y: (lat - anchor.latitude) * perDegLat,
        );

    var poly = [for (final v in ring) toM(v.latitude, v.longitude)];
    final me = toM(poles[p].latitude, poles[p].longitude);
    for (final q in owners) {
      if (q == p) continue;
      final other = toM(poles[q].latitude, poles[q].longitude);
      poly = _clipHalfPlane(poly, me, other);
      if (poly.length < 3) return null;
    }
    return [
      for (final m in poly)
        LatLng(
          anchor.latitude + m.y / perDegLat,
          anchor.longitude + m.x / perDegLon,
        ),
    ];
  }

  static List<_Pt> _clipHalfPlane(List<_Pt> polygon, _Pt inside, _Pt outside) {
    if (polygon.isEmpty) return polygon;
    final mx = (inside.x + outside.x) / 2;
    final my = (inside.y + outside.y) / 2;
    final nx = outside.x - inside.x;
    final ny = outside.y - inside.y;
    double sd(_Pt v) => (v.x - mx) * nx + (v.y - my) * ny;
    _Pt intersect(_Pt a, _Pt b) {
      final da = sd(a), db = sd(b);
      final t = da / (da - db);
      return (x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y));
    }

    final out = <_Pt>[];
    for (var i = 0; i < polygon.length; i++) {
      final cur = polygon[i];
      final prev = polygon[(i - 1 + polygon.length) % polygon.length];
      final curIn = sd(cur) <= 0;
      final prevIn = sd(prev) <= 0;
      if (curIn) {
        if (!prevIn) out.add(intersect(prev, cur));
        out.add(cur);
      } else if (prevIn) {
        out.add(intersect(prev, cur));
      }
    }
    return out;
  }

  // ── Assignment (memoised; static for fixed blocks + pole positions) ──

  static Object? _cacheKey;
  static List<int?>? _cacheAssign;

  static List<int?> _assignmentFor(
    List<TerritoryBlock> blocks,
    List<Pole> poles,
    double maxAssignMeters,
  ) {
    final key = Object.hash(
      identityHashCode(blocks),
      poles.length,
      Object.hashAll(poles.map((p) => '${p.id}:${p.latitude}:${p.longitude}')),
      maxAssignMeters,
    );
    if (key == _cacheKey && _cacheAssign != null) return _cacheAssign!;

    final assign = List<int?>.filled(poles.length, null);
    for (var p = 0; p < poles.length; p++) {
      assign[p] = _blockForPole(poles[p], blocks, maxAssignMeters);
    }
    _cacheKey = key;
    _cacheAssign = assign;
    return assign;
  }

  static int? _blockForPole(
    Pole pole,
    List<TerritoryBlock> blocks,
    double maxAssignMeters,
  ) {
    final perDegLat = 111000.0;
    final perDegLon = 111000.0 * math.cos(pole.latitude * math.pi / 180);

    int? inside;
    var insideD = double.infinity;
    int? near;
    var nearD = double.infinity;

    for (var b = 0; b < blocks.length; b++) {
      final c = blocks[b].centroid;
      final dx = (c.longitude - pole.longitude) * perDegLon;
      final dy = (c.latitude - pole.latitude) * perDegLat;
      final d = dx * dx + dy * dy;
      if (_contains(blocks[b].ring, pole.latitude, pole.longitude)) {
        if (d < insideD) {
          insideD = d;
          inside = b;
        }
      } else if (d < nearD) {
        nearD = d;
        near = b;
      }
    }
    if (inside != null) return inside;
    if (near != null && nearD <= maxAssignMeters * maxAssignMeters) return near;
    return null;
  }

  // ── Empty puzzlet-blocks per pole (memoised; geometry-only) ──

  static Object? _candKey;
  static Map<int, Set<int>>? _candCache;

  static Map<int, Set<int>> _candidatesFor(
    List<TerritoryBlock> blocks,
    List<Pole> poles,
    Map<String, List<LatLng>> pts,
    Set<int> occupied,
  ) {
    final key = Object.hash(
      identityHashCode(blocks),
      identityHashCode(pts),
      Object.hashAll(poles.map((p) => '${p.id}:${p.latitude}:${p.longitude}')),
      Object.hashAll(occupied),
    );
    if (key == _candKey && _candCache != null) return _candCache!;

    final idToIdx = <String, int>{};
    for (var i = 0; i < poles.length; i++) {
      idToIdx[poles[i].id] = i;
    }
    final out = <int, Set<int>>{};
    pts.forEach((poleId, points) {
      final pi = idToIdx[poleId];
      if (pi == null) return;
      for (final pt in points) {
        final b = _blockContaining(blocks, pt);
        if (b == null || occupied.contains(b)) continue;
        (out[pi] ??= {}).add(b);
      }
    });
    _candKey = key;
    _candCache = out;
    return out;
  }

  static int? _blockContaining(List<TerritoryBlock> blocks, LatLng pt) {
    for (var b = 0; b < blocks.length; b++) {
      if (_contains(blocks[b].ring, pt.latitude, pt.longitude)) return b;
    }
    return null;
  }

  // ── Adjacency (memoised): blocks sharing an edge (≥2 snapped vertices) ──

  static Object? _adjKey;
  static List<Set<int>>? _adjCache;

  static List<Set<int>> _adjacencyFor(List<TerritoryBlock> blocks) {
    final key = Object.hash(identityHashCode(blocks), blocks.length);
    if (key == _adjKey && _adjCache != null) return _adjCache!;

    // snapped vertex (~1 m) → blocks touching it.
    final byVertex = <String, List<int>>{};
    for (var b = 0; b < blocks.length; b++) {
      final seen = <String>{};
      for (final v in blocks[b].ring) {
        final k = '${(v.latitude * 1e5).round()}:${(v.longitude * 1e5).round()}';
        if (seen.add(k)) (byVertex[k] ??= []).add(b);
      }
    }
    // Count shared vertices per block pair; ≥2 ⇒ a shared edge ⇒ adjacent.
    final shared = <int, Map<int, int>>{};
    for (final bl in byVertex.values) {
      for (var i = 0; i < bl.length; i++) {
        for (var j = i + 1; j < bl.length; j++) {
          final a = bl[i], c = bl[j];
          (shared[a] ??= {}).update(c, (x) => x + 1, ifAbsent: () => 1);
          (shared[c] ??= {}).update(a, (x) => x + 1, ifAbsent: () => 1);
        }
      }
    }
    final adj = List.generate(blocks.length, (_) => <int>{});
    shared.forEach((b, others) {
      others.forEach((o, n) {
        if (n >= 2) adj[b].add(o);
      });
    });
    _adjKey = key;
    _adjCache = adj;
    return adj;
  }

  // ── Hull-bounded fill (block-level Voronoi; memoised, geometry-only) ──

  static Object? _fillKey;
  static Map<int, int>? _fillCache;

  static Map<int, int> _fillFor(
    List<TerritoryBlock> blocks,
    List<Pole> poles,
    List<LatLng> seeds,
    Set<int> occupied,
  ) {
    final key = Object.hash(
      identityHashCode(blocks),
      Object.hashAll(poles.map((p) => '${p.id}:${p.latitude}:${p.longitude}')),
      Object.hashAll(occupied),
      seeds.length,
    );
    if (key == _fillKey && _fillCache != null) return _fillCache!;

    final hull = _convexHull(seeds);
    final out = <int, int>{};
    for (var b = 0; b < blocks.length; b++) {
      if (occupied.contains(b)) continue;
      final c = blocks[b].centroid;
      if (!_inHull(hull, c)) continue;
      final perDegLon = 111000.0 * math.cos(c.latitude * math.pi / 180);
      var best = -1;
      var bestD = double.infinity;
      for (var p = 0; p < poles.length; p++) {
        final dx = (poles[p].longitude - c.longitude) * perDegLon;
        final dy = (poles[p].latitude - c.latitude) * 111000.0;
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
      if (best >= 0) out[b] = best;
    }
    _fillKey = key;
    _fillCache = out;
    return out;
  }

  /// Andrew's monotone chain, on (lng=x, lat=y). Returns the hull as a CCW
  /// ring; distances are tiny at event scale so raw degrees are fine.
  static List<LatLng> _convexHull(List<LatLng> pts) {
    if (pts.length < 3) return pts;
    final p = [...pts]..sort((a, b) => a.longitude != b.longitude
        ? a.longitude.compareTo(b.longitude)
        : a.latitude.compareTo(b.latitude));
    double cross(LatLng o, LatLng a, LatLng b) =>
        (a.longitude - o.longitude) * (b.latitude - o.latitude) -
        (a.latitude - o.latitude) * (b.longitude - o.longitude);
    final lower = <LatLng>[];
    for (final q in p) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    final upper = <LatLng>[];
    for (final q in p.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    lower.removeLast();
    upper.removeLast();
    return [...lower, ...upper];
  }

  /// Point in a CCW convex hull — left-of (or on) every directed edge.
  static bool _inHull(List<LatLng> hull, LatLng pt) {
    if (hull.length < 3) return false;
    for (var i = 0; i < hull.length; i++) {
      final a = hull[i], b = hull[(i + 1) % hull.length];
      final cross = (b.longitude - a.longitude) * (pt.latitude - a.latitude) -
          (b.latitude - a.latitude) * (pt.longitude - a.longitude);
      if (cross < 0) return false;
    }
    return true;
  }

  /// Ray-casting point-in-polygon on the (lat,lng) ring.
  static bool _contains(List<LatLng> ring, double lat, double lng) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final yi = ring[i].latitude, xi = ring[i].longitude;
      final yj = ring[j].latitude, xj = ring[j].longitude;
      final intersects = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersects) inside = !inside;
    }
    return inside;
  }
}

typedef _Pt = ({double x, double y});
