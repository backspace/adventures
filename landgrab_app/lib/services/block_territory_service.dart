import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// EXPERIMENT (street-aware territory, see
/// ~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md).
///
/// Loads pre-computed city-block polygons from a bundled GeoJSON asset so
/// captured territory can follow the street grid instead of the abstract
/// Voronoi cell. The blocks are static for a fixed venue, so they're
/// generated offline (see tool/territory/generate_blocks.py) and dropped in
/// at `assets/experimental/blocks.geojson`.
///
/// When the asset is absent, empty, or malformed this returns null and the
/// map falls back to the existing [TerritoryLayer] — so the experiment is
/// entirely opt-in by presence of the file.
class TerritoryBlock {
  final String id;

  /// Outer ring, closed or not (we don't rely on closure).
  final List<LatLng> ring;

  /// Vertex-average centroid — good enough for nearest-pole assignment.
  final LatLng centroid;

  const TerritoryBlock({
    required this.id,
    required this.ring,
    required this.centroid,
  });
}

/// A pre-dissolved, contiguous territory shape for one pole, produced offline
/// by tool/territory/assign_territory.py. The app colours it by the pole's
/// current owner and taps it for ownership — one authoritative shape used for
/// both, so colour and tap never disagree.
class TerritoryRegion {
  final String poleId;
  final List<LatLng> ring;
  const TerritoryRegion({required this.poleId, required this.ring});
}

class BlockTerritoryService {
  static const _asset = 'assets/experimental/blocks.geojson';
  static const _puzzletAsset = 'assets/experimental/puzzlet_points.geojson';
  static const _territoryAsset = 'assets/experimental/territory.geojson';

  /// Parse the blocks asset, or null if it isn't there / can't be read.
  static Future<List<TerritoryBlock>?> load() async {
    try {
      final raw = (await rootBundle.loadString(_asset)).trim();
      if (raw.isEmpty) return null;
      return parse(raw);
    } catch (_) {
      // Missing asset (the common case until someone generates it) or
      // malformed JSON — either way, let the caller fall back to Voronoi.
      return null;
    }
  }

  /// Pre-dissolved per-pole territory shapes, or null if absent. When present,
  /// this supersedes the raw blocks path: the app renders/tap-tests these
  /// directly instead of assigning blocks live.
  static Future<List<TerritoryRegion>?> loadTerritory() async {
    try {
      final raw = (await rootBundle.loadString(_territoryAsset)).trim();
      if (raw.isEmpty) return null;
      return parseTerritory(raw);
    } catch (_) {
      return null;
    }
  }

  /// Parse a GeoJSON FeatureCollection of Polygon / MultiPolygon features
  /// carrying a `pole_id`. Exposed for testing.
  static List<TerritoryRegion>? parseTerritory(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final features = json['features'];
      if (features is! List) return null;
      final out = <TerritoryRegion>[];
      for (final f in features) {
        if (f is! Map) continue;
        final props = f['properties'];
        final poleId = props is Map ? props['pole_id']?.toString() : null;
        final geom = f['geometry'];
        if (poleId == null || geom is! Map) continue;
        final coords = geom['coordinates'];
        final rings = <List<LatLng>>[];
        switch (geom['type']) {
          case 'Polygon':
            if (coords is List && coords.isNotEmpty) rings.add(_ring(coords.first));
          case 'MultiPolygon':
            if (coords is List) {
              for (final poly in coords) {
                if (poly is List && poly.isNotEmpty) rings.add(_ring(poly.first));
              }
            }
        }
        for (final ring in rings) {
          if (ring.length >= 3) out.add(TerritoryRegion(poleId: poleId, ring: ring));
        }
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// EXPERIMENT (step 1): puzzlet locations grouped by their pole id, so a
  /// pole's territory can extend into a puzzlet's block. Local-only asset
  /// (dumped from the dev DB) — null when absent. NOTE: this bundles raw
  /// puzzlet coordinates in the client, which is fine for a local look-test
  /// but NOT shippable; production computes this server-side (see the design
  /// doc's deployment section).
  static Future<Map<String, List<LatLng>>?> loadPuzzletPoints() async {
    try {
      final raw = (await rootBundle.loadString(_puzzletAsset)).trim();
      if (raw.isEmpty) return null;
      return parsePuzzletPoints(raw);
    } catch (_) {
      return null;
    }
  }

  /// Parse a GeoJSON FeatureCollection of Point features carrying a
  /// `pole_id` property → { pole_id: [points] }. Exposed for testing.
  static Map<String, List<LatLng>>? parsePuzzletPoints(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final features = json['features'];
      if (features is! List) return null;
      final out = <String, List<LatLng>>{};
      for (final f in features) {
        if (f is! Map) continue;
        final props = f['properties'];
        final poleId = props is Map ? props['pole_id']?.toString() : null;
        final geom = f['geometry'];
        if (poleId == null || geom is! Map || geom['type'] != 'Point') continue;
        final c = geom['coordinates'];
        if (c is! List || c.length < 2) continue;
        (out[poleId] ??= []).add(
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        );
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Parse a GeoJSON FeatureCollection of Polygon / MultiPolygon features
  /// (coordinates in GeoJSON [lng, lat] order). Returns null on anything
  /// malformed or empty, so callers can fall back cleanly. Exposed for testing.
  static List<TerritoryBlock>? parse(String raw) {
    try {
      return _parse(raw);
    } catch (_) {
      return null;
    }
  }

  static List<TerritoryBlock>? _parse(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map) return null;
    final features = json['features'];
    if (features is! List) return null;

    final blocks = <TerritoryBlock>[];
    var auto = 0;
    for (final f in features) {
      if (f is! Map) continue;
      final geom = f['geometry'];
      if (geom is! Map) continue;
      final coords = geom['coordinates'];
      final rings = <List<LatLng>>[];
      switch (geom['type']) {
        case 'Polygon':
          if (coords is List && coords.isNotEmpty) {
            rings.add(_ring(coords.first));
          }
        case 'MultiPolygon':
          if (coords is List) {
            for (final poly in coords) {
              if (poly is List && poly.isNotEmpty) rings.add(_ring(poly.first));
            }
          }
      }
      final props = f['properties'];
      final baseId = (props is Map ? props['id'] : null)?.toString();
      for (final ring in rings) {
        if (ring.length < 3) continue;
        blocks.add(TerritoryBlock(
          id: baseId ?? 'b${auto++}',
          ring: ring,
          centroid: _centroid(ring),
        ));
      }
    }
    return blocks.isEmpty ? null : blocks;
  }

  static List<LatLng> _ring(dynamic coordsRing) {
    if (coordsRing is! List) return const [];
    final out = <LatLng>[];
    for (final c in coordsRing) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        out.add(LatLng(lat, lng));
      }
    }
    return out;
  }

  static LatLng _centroid(List<LatLng> ring) {
    var lat = 0.0, lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
  }
}
