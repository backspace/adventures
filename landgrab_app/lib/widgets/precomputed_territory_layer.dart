import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/pole.dart';
import 'package:landgrab/services/block_territory_service.dart';
import 'package:landgrab/widgets/team_style.dart';

/// EXPERIMENT: renders pre-computed, per-pole territory shapes
/// ([TerritoryRegion], from tool/territory/assign_territory.py). Each region
/// is one dissolved, contiguous polygon, coloured by its pole's current owner
/// — so a zone has no internal lines, no gaps, and the tapped owner always
/// matches the colour (the map's tap handler tests these same shapes).
///
/// Design + rationale:
/// ~/Documents/Events/poles/Concepts/landgrab-street-aware-territory.md
///
/// Note: dissolve is per *pole*, so two adjacent poles held by the *same team*
/// still meet on a line. That's a much smaller case than the old per-block
/// lines; a true per-team merge would need dynamic (server-side) dissolve.
class PrecomputedTerritoryLayer extends StatelessWidget {
  final List<TerritoryRegion> regions;
  final List<Pole> poles;
  final String? myOwnerId;
  final Map<String, int> colorIndexByTeam;

  const PrecomputedTerritoryLayer({
    super.key,
    required this.regions,
    required this.poles,
    this.myOwnerId,
    this.colorIndexByTeam = const {},
  });

  @override
  Widget build(BuildContext context) {
    final ownerByPole = <String, String>{};
    for (final p in poles) {
      final o = p.currentOwnerTeamId;
      if (o != null) ownerByPole[p.id] = o;
    }

    // Rivals first, mine last — same paint order as TerritoryLayer.
    final rivals = <Polygon>[];
    final mine = <Polygon>[];
    for (final r in regions) {
      final owner = ownerByPole[r.poleId];
      if (owner == null) continue; // pole not captured → no fill
      if (owner == myOwnerId) {
        mine.addAll(_myPolygons(r.ring, r.holes, owner));
      } else {
        rivals.add(_fill(r.ring, r.holes, owner));
      }
    }
    return PolygonLayer(polygons: [...rivals, ...mine]);
  }

  Color _colorFor(String ownerId) {
    final index = colorIndexByTeam[ownerId];
    if (index == null) return Colors.blueGrey;
    return TeamStyle.forIndex(index).color;
  }

  Polygon _fill(List<LatLng> points, List<List<LatLng>> holes, String ownerId) {
    final color = _colorFor(ownerId);
    return Polygon(
      points: points,
      holePointsList: holes.isEmpty ? null : holes,
      color: color.withValues(alpha: 0.26),
      borderColor: color.withValues(alpha: 0.7),
      borderStrokeWidth: 1.5,
      isFilled: true,
    );
  }

  List<Polygon> _myPolygons(
      List<LatLng> points, List<List<LatLng>> holes, String ownerId) {
    final color = _colorFor(ownerId);
    final holeList = holes.isEmpty ? null : holes;
    return [
      Polygon(
        points: points,
        holePointsList: holeList,
        color: color.withValues(alpha: 0.40),
        borderStrokeWidth: 0,
        isFilled: true,
      ),
      Polygon(
        points: points,
        holePointsList: holeList,
        isFilled: false,
        borderStrokeWidth: 4.5,
        borderColor: Colors.black.withValues(alpha: 0.55),
      ),
      Polygon(
        points: points,
        holePointsList: holeList,
        isFilled: false,
        borderStrokeWidth: 2.5,
        borderColor: Colors.white,
      ),
    ];
  }
}
