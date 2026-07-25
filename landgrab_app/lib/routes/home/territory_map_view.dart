import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/home/map_markers.dart';
import 'package:landgrab/services/block_territory_service.dart';
import 'package:landgrab/widgets/attack_rings_layer.dart';
import 'package:landgrab/widgets/bathroom_layer.dart';
import 'package:landgrab/widgets/block_territory_layer.dart';
import 'package:landgrab/widgets/capture_rings_layer.dart';
import 'package:landgrab/widgets/highlight_reticle.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:landgrab/widgets/liberated_zone_layer.dart';
import 'package:landgrab/widgets/live_location_layer.dart';
import 'package:landgrab/widgets/pole_pop_layer.dart';
import 'package:landgrab/widgets/precomputed_territory_layer.dart';
import 'package:landgrab/widgets/team_style.dart';
import 'package:landgrab/widgets/territory_layer.dart';
import 'package:landgrab/widgets/territory_pattern_layer.dart';
import 'package:landgrab/widgets/zone_flash_layer.dart';

/// The gameplay map: the tile basemap, territory fills (pre-dissolved,
/// live-block, or Voronoi), the liberated-zone hatch, bathroom/capture/attack
/// overlays, pole markers, validator-only stars, and the user's location +
/// compass. Purely presentational — HomeRoute owns the state and passes in the
/// data and callbacks. Overlays that sit *beside* the map (in-progress card,
/// locate button, chips) stay in HomeRoute's Stack.
class TerritoryMapView extends StatelessWidget {
  final MapController mapController;

  /// First-frame camera. [initialCameraFit] (when non-null) fits the poles and
  /// wins over [initialCenter]/[initialZoom]; the parent passes the saved
  /// camera via the latter when there's a remembered view. flutter_map applies
  /// whichever only on the first frame, so later pans are untouched.
  final CameraFit? initialCameraFit;
  final LatLng initialCenter;
  final double initialZoom;

  /// A tap on open map space (used to resolve which zone/pole was tapped).
  final void Function(LatLng point) onMapTap;

  /// Every camera change: centre, zoom, and whether it was a user gesture — so
  /// the parent can size zoom-scaled overlays and remember a deliberate pan.
  final void Function(LatLng? center, double? zoom, bool hasGesture)
      onCameraChanged;

  // Territory sources, in precedence order: pre-dissolved per-pole shapes,
  // then live blocks, else the Voronoi fallback.
  final List<TerritoryRegion>? territory;
  final List<TerritoryBlock>? territoryBlocks;
  final Map<String, List<LatLng>>? puzzletPoints;

  final List<Pole> poles;
  final String? teamId;
  final Map<String, int> colorIndexByTeam;

  // My team has joined the subversion: my own zones drop their white cased
  // outline (a liberator isn't holding ground).
  final bool joinedSubversion;

  // Capture-animation state (drives the Voronoi fill + capture rings).
  final Map<String, DateTime> captureStartedAt;
  final Map<String, String?> captureFromOwner;
  final Duration captureAnimationDuration;

  // Tap-link animations: pole id → when a pop (tapped its zone) or flash
  // (tapped the pole) began. Purged by the parent's ticker.
  final Map<String, DateTime> polePopAt;
  final Duration polePopDuration;
  final Map<String, DateTime> zoneFlashAt;
  final Duration zoneFlashDuration;

  // Liberated-zone hatch.
  final List<LiberatedShape> liberatedShapes;
  final double pulsePhase;
  final LiberatedZoneStyle liberatedStyle;

  final List<Bathroom> bathrooms;
  final Set<String> attackedPoleIds;
  final String? highlightedPoleId;

  // Poles the endgame boundary hasn't passed (the markers to draw), plus how
  // to tap each. Pins are a single consistent colour now, so there's no
  // per-pole style callback.
  final List<Pole> polesInPlay;
  final void Function(Pole pole) onPoleTap;

  // Prebuilt validator-only puzzlet markers (empty for players).
  final List<Marker> validatorOnlyMarkers;

  const TerritoryMapView({
    super.key,
    required this.mapController,
    required this.initialCameraFit,
    required this.initialCenter,
    required this.initialZoom,
    required this.onMapTap,
    required this.onCameraChanged,
    required this.territory,
    required this.territoryBlocks,
    required this.puzzletPoints,
    required this.poles,
    required this.teamId,
    required this.colorIndexByTeam,
    this.joinedSubversion = false,
    required this.captureStartedAt,
    required this.captureFromOwner,
    required this.captureAnimationDuration,
    required this.polePopAt,
    required this.polePopDuration,
    required this.zoneFlashAt,
    required this.zoneFlashDuration,
    required this.liberatedShapes,
    required this.pulsePhase,
    required this.liberatedStyle,
    required this.bathrooms,
    required this.attackedPoleIds,
    required this.highlightedPoleId,
    required this.polesInPlay,
    required this.onPoleTap,
    required this.validatorOnlyMarkers,
  });

  // PROTOTYPE: per-team hatch over the pre-dissolved territory fills, so teams
  // that share a palette colour (rosters past 12) read apart by texture. Only
  // owned regions whose team has a non-solid pattern are textured — so with ≤12
  // teams this is empty and the pattern layer renders nothing. Mirrors
  // PrecomputedTerritoryLayer's owner resolution (region.poleId → pole owner).
  List<TerritoryPatternShape> _precomputedPatternShapes() {
    final regions = territory;
    if (regions == null) return const [];

    final ownerByPole = <String, String>{};
    for (final p in poles) {
      final o = p.currentOwnerTeamId;
      if (o != null) ownerByPole[p.id] = o;
    }

    final out = <TerritoryPatternShape>[];
    for (final r in regions) {
      final owner = ownerByPole[r.poleId];
      if (owner == null) continue; // uncaptured → no fill, no pattern
      final index = colorIndexByTeam[owner];
      if (index == null) continue;

      final style = TeamStyle.forIndex(index);
      // Preview forces a varied non-solid band onto every zone so the look can
      // be judged without a 13+ team roster; real behaviour uses the team's
      // own pattern (solid for the first 12, textured beyond).
      final pattern = kPreviewAllZonePatterns
          ? TeamPattern
              .values[1 + (index % (TeamPattern.values.length - 1))]
          : style.pattern;
      if (pattern == TeamPattern.solid) continue;

      out.add(TerritoryPatternShape(
        ring: r.ring,
        holes: r.holes,
        pattern: pattern,
        color: style.color,
      ));
    }
    return out;
  }

  // Flash shapes for zones whose pole was just tapped. Precomputed geometry
  // only (the block/Voronoi paths have no ready per-pole ring); the pop still
  // fires there, just without a matching zone flash.
  List<ZoneFlashShape> _zoneFlashShapes() {
    final regions = territory;
    if (regions == null || zoneFlashAt.isEmpty) return const [];
    final byPole = {for (final p in poles) p.id: p};
    final now = DateTime.now();
    final out = <ZoneFlashShape>[];
    for (final r in regions) {
      final start = zoneFlashAt[r.poleId];
      if (start == null) continue;
      // Only flash a zone that's actually painted (owned or liberated) — an
      // unclaimed pole has no fill, so there's nothing to point at.
      final pole = byPole[r.poleId];
      if (pole == null ||
          (pole.currentOwnerTeamId == null && !pole.liberated)) {
        continue;
      }
      final t = (now.difference(start).inMicroseconds / 1000 /
              zoneFlashDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      out.add(ZoneFlashShape(ring: r.ring, holes: r.holes, progress: t));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        // A remembered camera comes in via initialCenter/Zoom; the first-ever
        // view fits the poles via initialCameraFit (which overrides them).
        initialCameraFit: initialCameraFit,
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        // Tap a zone to see who holds it.
        onTap: (_, point) => onMapTap(point),
        // Make rotation deliberate: the gesture race commits a two-finger
        // gesture to whichever intent (zoom/move/rotate) crosses its
        // threshold first, and the raised rotation threshold means a casual
        // twist mid-pinch stays a zoom. North is always restorable via the
        // compass button.
        interactionOptions: const InteractionOptions(
          enableMultiFingerGestureRace: true,
          rotationThreshold: 25,
        ),
        onPositionChanged: (position, hasGesture) =>
            onCameraChanged(position.center, position.zoom, hasGesture),
      ),
      children: [
        landgrabTileLayer(context),
        // Territory fills sit above the tiles and below the marker pins so pole
        // icons remain readable over their own coloured cells. Prefer
        // pre-dissolved per-pole shapes; then the live block path; else the
        // Voronoi layer.
        if (territory != null) ...[
          PrecomputedTerritoryLayer(
            regions: territory!,
            poles: poles,
            myOwnerId: teamId,
            colorIndexByTeam: colorIndexByTeam,
            joinedSubversion: joinedSubversion,
          ),
          // Per-team hatch over the fills (empty for ≤12 teams). Above the
          // colour fill, below the pins.
          TerritoryPatternLayer(shapes: _precomputedPatternShapes()),
        ] else if (territoryBlocks != null)
          BlockTerritoryLayer(
            blocks: territoryBlocks!,
            poles: poles,
            myOwnerId: teamId,
            colorIndexByTeam: colorIndexByTeam,
            puzzletPointsByPole: puzzletPoints,
            joinedSubversion: joinedSubversion,
          )
        else
          TerritoryLayer(
            poles: poles,
            myOwnerId: teamId,
            colorIndexByTeam: colorIndexByTeam,
            captureStartedAt: captureStartedAt,
            captureFromOwner: captureFromOwner,
            captureAnimationDuration: captureAnimationDuration,
            joinedSubversion: joinedSubversion,
          ),
        // Moving hatch over freed ground, above the static fill and below the
        // pins. Empty (and free) unless zones are liberated.
        LiberatedZoneLayer(
          shapes: liberatedShapes,
          phase: pulsePhase,
          style: liberatedStyle,
        ),
        // Brief white flash over a zone whose pole was just tapped.
        ZoneFlashLayer(shapes: _zoneFlashShapes()),
        BathroomLayer(bathrooms: bathrooms),
        CaptureRingsLayer(
          poles: poles,
          captureStartedAt: captureStartedAt,
          duration: captureAnimationDuration,
          myOwnerId: teamId,
          colorIndexByTeam: colorIndexByTeam,
        ),
        AttackRingsLayer(
          poles: poles,
          attackedPoleIds: attackedPoleIds,
          pulsePhase: pulsePhase,
        ),
        // Ripple out of a pole whose zone was just tapped.
        PolePopLayer(
          poles: poles,
          poppedAt: polePopAt,
          duration: polePopDuration,
        ),
        // Transient "which one" reticle from a notification's "View on map".
        if (highlightedPoleId != null)
          MarkerLayer(markers: [
            for (final pole in poles)
              if (pole.id == highlightedPoleId)
                Marker(
                  point: LatLng(pole.latitude, pole.longitude),
                  width: 120,
                  height: 120,
                  child: HighlightReticle(phase: pulsePhase),
                ),
          ]),
        MarkerLayer(
          // The endgame boundary is invisible by design: poles it has passed
          // just disappear (their territory stays), so players sense the
          // squeeze without seeing a circle.
          markers: polesInPlay.map((pole) {
            final dot = PoleDot(
              isMine: pole.currentOwnerTeamId == teamId,
              prohibitive: pole.prohibitive,
              locked: pole.locked,
            );
            // Stakes carrying accessibility notes/tags wear a small info badge
            // at their edge; they get a slightly larger box so it doesn't clip.
            final hasA11y = pole.hasAccessibilityInfo;
            return Marker(
              // Keyed by pole so zoom-time culling can't hand this element a
              // different pole — unkeyed, PoleDot's AnimatedContainer tweened
              // between neighbouring poles' colours on every reshuffle.
              key: ValueKey(pole.id),
              point: LatLng(pole.latitude, pole.longitude),
              width: hasA11y ? 18 : 12,
              height: hasA11y ? 18 : 12,
              // A direct tap on the marker always names the stake — the only
              // way to reveal an unclaimed one, since its blank surroundings
              // don't respond.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPoleTap(pole),
                child: Tooltip(
                  message: pole.name,
                  child: hasA11y
                      ? Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            SizedBox(width: 12, height: 12, child: dot),
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: AccessibilityInfoBadge(),
                            ),
                          ],
                        )
                      : dot,
                ),
              ),
            );
          }).toList(),
        ),
        // Validator-only puzzlets: rendered outside the pole/cluster stack so
        // they never spider with other markers.
        if (validatorOnlyMarkers.isNotEmpty)
          MarkerLayer(markers: validatorOnlyMarkers),
        // User's own position + heading cone (only while walking). Above the
        // pole markers so a pole directly under the user doesn't obscure the
        // marker; below attribution/compass.
        const LiveLocationLayer(),
        const MapAttribution(),
        // Compass appears only when the map is rotated; tap animates it back to
        // north-up. The plugin picks up the enclosing FlutterMap's controller
        // via context — no controller wiring on our side.
        const MapCompass.cupertino(hideIfRotatedNorth: true),
      ],
    );
  }
}
