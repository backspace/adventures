import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/widgets/map_pin.dart';

/// Shared FlutterMap configuration: CartoDB Positron tiles, attribution, and
/// a marker layer. Used for both mini-thumbnails and full-screen views.
///
/// With [drawMode] on, a one-finger drag draws a freehand polygon
/// (finished shape, 3+ points, handed to [onPolygonDrawn]) while
/// two-finger gestures still pan and zoom the map — so the supervisor
/// can frame the area before/while tracing it. [polygon] renders a
/// committed shape; the caller owns that state so the drawn area can
/// outlive draw mode.
///
/// Drawing uses a passive [Listener] rather than a pan recognizer:
/// it doesn't enter the gesture arena, so the map's own two-finger
/// recognizers keep working alongside it. Single-finger drag is left
/// disabled on the map so it belongs solely to drawing.
/// Remembers each opted-in map's last manually-set camera (by key) for
/// the session, so a pan/zoom survives leaving and returning to the
/// screen. In-memory only — resets on app restart.
final Map<String, _CameraSnapshot> _cameraMemory = {};

class _CameraSnapshot {
  final LatLng center;
  final double zoom;
  const _CameraSnapshot(this.center, this.zoom);
}

class PinMap extends StatefulWidget {
  final List<MapPin> pins;
  final bool interactive;
  final bool drawMode;
  final void Function(List<LatLng> polygon)? onPolygonDrawn;
  final List<LatLng>? polygon;

  /// When set, this map remembers its camera under this key: a manual
  /// pan/zoom is restored on the next build instead of re-fitting to the
  /// pins, so returning to the screen keeps the same view. Leave null to
  /// keep the default fit-to-pins behaviour.
  final String? cameraMemoryKey;

  /// Declutter behaviour (on by default so all the survey maps act
  /// alike). Above a zoom threshold, overlapping pins repulse apart so
  /// each stays visible; below it they collapse into a tappable count
  /// badge. Set false for maps that should plot pins verbatim.
  final bool cluster;

  /// Plot pins that share a [MapPin.regionId] around the region's
  /// centroid (averaging out noisy in-building GPS). On by default;
  /// requires the caller to tag puzzlet pins with their region.
  final bool groupByRegion;

  const PinMap({
    super.key,
    required this.pins,
    this.interactive = true,
    this.drawMode = false,
    this.onPolygonDrawn,
    this.polygon,
    this.cameraMemoryKey,
    this.cluster = true,
    this.groupByRegion = true,
  });

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  final MapController _controller = MapController();
  LatLng? _userLocation;
  bool _locating = false;

  // Debounces persisting the camera to UiPreferences — onPositionChanged
  // fires every frame of a pan/zoom, so we only write once it settles.
  Timer? _persistTimer;

  // Last zoom we reacted to, so declutter only recomputes when the zoom
  // actually changes (see _onPositionChanged).
  double? _lastZoom;

  // Debounces the declutter recompute so pins don't reshuffle every frame
  // of a pinch — they ride the zoom smoothly and re-settle once it stops.
  Timer? _declutterTimer;

  // Below this zoom (far out) overlapping pins collapse into count
  // badges; above it they repulse (displace) so each stays visible.
  static const double _clusterBelowZoom = 15.5;

  @override
  void initState() {
    super.initState();
    final key = widget.cameraMemoryKey;
    // First open this session: pull the saved camera from disk. Later
    // opens hit the in-memory cache synchronously (via _remembered).
    if (key != null && !_cameraMemory.containsKey(key)) {
      _hydrateCamera(key);
    }
    // Declutter needs the laid-out camera; nudge a rebuild once it's ready.
    if (widget.cluster) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _hydrateCamera(String key) async {
    final saved = await UiPreferences.getMapCamera(key);
    if (saved == null || !mounted) return;
    // If the user already panned this session, their gesture wins.
    if (_cameraMemory.containsKey(key)) return;
    final center = LatLng(saved.lat, saved.lng);
    _cameraMemory[key] = _CameraSnapshot(center, saved.zoom);
    // The first frame already fit to the pins; move to the saved view.
    try {
      _controller.move(center, saved.zoom);
    } catch (_) {
      // Camera not laid out yet; the next build uses _remembered anyway.
    }
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _declutterTimer?.cancel();
    // Flush a pending camera write so a quick pan-then-leave still saves.
    final key = widget.cameraMemoryKey;
    final snap = key == null ? null : _cameraMemory[key];
    if (key != null && snap != null) {
      UiPreferences.setMapCamera(key,
          lat: snap.center.latitude, lng: snap.center.longitude, zoom: snap.zoom);
    }
    super.dispose();
  }

  // In-progress freehand stroke, already unprojected. A stroke only
  // counts while exactly one finger is down for its whole duration —
  // the moment a second finger lands it's a map nav gesture, not a
  // draw, so we abandon the partial stroke. The camera stays put
  // during a valid (single-finger) stroke, so converting each point
  // as it arrives is safe.
  final List<LatLng> _stroke = [];
  final Set<int> _pointers = {};
  bool _strokeValid = false;

  void _addStrokePoint(Offset local) {
    try {
      _stroke.add(_controller.camera.pointToLatLng(Point(local.dx, local.dy)));
    } catch (_) {
      // Camera not laid out yet; drop the point.
    }
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length == 1) {
      _strokeValid = true;
      setState(() {
        _stroke.clear();
        _addStrokePoint(e.localPosition);
      });
    } else {
      // Second finger → two-finger map gesture; this isn't a draw.
      _strokeValid = false;
      if (_stroke.isNotEmpty) setState(_stroke.clear);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_strokeValid || _pointers.length != 1) return;
    setState(() => _addStrokePoint(e.localPosition));
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    if (_strokeValid && _stroke.length >= 3) {
      widget.onPolygonDrawn?.call(List.of(_stroke));
    }
    _strokeValid = false;
    if (_stroke.isNotEmpty) setState(_stroke.clear);
  }

  _CameraSnapshot? get _remembered {
    final key = widget.cameraMemoryKey;
    return key == null ? null : _cameraMemory[key];
  }

  void _onPositionChanged(MapPosition pos, bool hasGesture) {
    final zoom = pos.zoom;

    // Camera memory — only deliberate pans/zooms, not the initial fit.
    final key = widget.cameraMemoryKey;
    if (key != null && hasGesture) {
      final center = pos.center;
      if (center != null && zoom != null) {
        _cameraMemory[key] = _CameraSnapshot(center, zoom);
        // Persist once the gesture settles (fires every frame otherwise).
        _persistTimer?.cancel();
        _persistTimer = Timer(const Duration(milliseconds: 500), () {
          UiPreferences.setMapCamera(key,
              lat: center.latitude, lng: center.longitude, zoom: zoom);
        });
      }
    }

    // Declutter is zoom-dependent (pixel overlap), so recompute on zoom
    // change — but debounced, so a pinch doesn't reshuffle pins every
    // frame. During the gesture the markers are real coordinates, so
    // they scale smoothly with the map; they re-settle once it stops.
    // (Pans need nothing.)
    if (widget.cluster && zoom != null && zoom != _lastZoom) {
      _lastZoom = zoom;
      _declutterTimer?.cancel();
      _declutterTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(PinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A memory-keyed map owns its camera once shown — data reloads must
    // not yank it back to a fit.
    if (widget.cameraMemoryKey != null) return;
    if (_pinsMoved(oldWidget.pins, widget.pins) && _anyPinOutsideView()) {
      // Only refit when the new pin set is no longer visible — leaves
      // the user's manual pan/zoom alone when the move is still in view.
      try {
        _controller.fitCamera(_fit());
      } catch (_) {
        // Camera not laid out yet; ignore and let the next frame settle.
      }
    }
  }

  bool _pinsMoved(List<MapPin> a, List<MapPin> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].position != b[i].position) return true;
    }
    return false;
  }

  bool _anyPinOutsideView() {
    if (widget.pins.isEmpty) return false;
    try {
      final bounds = _controller.camera.visibleBounds;
      final c = _centroids;
      return widget.pins.any((p) => !bounds.contains(_effectivePos(p, c)));
    } catch (_) {
      return false;
    }
  }

  CameraFit _fit() {
    final c = _centroids;
    final coords = widget.pins.map((p) => _effectivePos(p, c)).toList();
    if (coords.length <= 1) {
      final position =
          coords.isEmpty ? const LatLng(49.8951, -97.1384) : coords.single;
      return CameraFit.coordinates(coordinates: [position], maxZoom: 17);
    }
    return CameraFit.coordinates(
      coordinates: coords,
      padding: const EdgeInsets.all(40),
      maxZoom: 17,
    );
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final fix = await LocationService.getCurrent(context: context);
      final me = LatLng(fix.latitude, fix.longitude);
      final zoom = max(_controller.camera.zoom, 15.0);
      _controller.move(me, zoom);
      if (!mounted) return;
      setState(() => _userLocation = me);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          // When location is permanently denied the OS won't re-prompt, so
          // offer a one-tap jump to Settings instead of a dead-end message.
          action: e is LocationPermissionDeniedException
              ? SnackBarAction(
                  label: LocationStrings.openSettings,
                  onPressed: LocationService.openAppSettings,
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  int _interactiveFlags() {
    if (!widget.interactive) return InteractiveFlag.none;
    if (widget.drawMode) {
      // Single-finger drag stays off (that's for drawing); two-finger
      // pan/zoom and double-tap zoom remain so the area can be framed.
      return InteractiveFlag.pinchZoom |
          InteractiveFlag.pinchMove |
          InteractiveFlag.doubleTapZoom |
          InteractiveFlag.flingAnimation;
    }
    return InteractiveFlag.all & ~InteractiveFlag.rotate;
  }

  // Beyond this the reading is "too imprecise" (see LocationFix.isAccurate)
  // and the circle would just be a huge distracting blob, so we skip it.
  static const double _maxAccuracyForCircle = 100;

  List<CircleMarker> get _accuracyCircles => widget.pins
      .where((p) =>
          p.accuracyM != null &&
          p.accuracyM! > 0 &&
          p.accuracyM! <= _maxAccuracyForCircle)
      .map((p) => CircleMarker(
            point: p.position,
            radius: p.accuracyM!,
            // Metres on the ground, so it scales with zoom.
            useRadiusInMeter: true,
            color: Colors.black.withValues(alpha: 0.06),
            borderColor: Colors.black.withValues(alpha: 0.25),
            borderStrokeWidth: 1,
          ))
      .toList();

  // Mean position per region, so a region's puzzlets group at one
  // believable spot rather than scattering with their noisy GPS.
  Map<String, LatLng> get _centroids {
    if (!widget.groupByRegion) return const {};
    final byRegion = <String, List<LatLng>>{};
    for (final p in widget.pins) {
      final rid = p.regionId;
      if (rid != null) (byRegion[rid] ??= []).add(p.position);
    }
    return {
      for (final e in byRegion.entries)
        e.key: LatLng(
          e.value.map((p) => p.latitude).reduce((a, b) => a + b) / e.value.length,
          e.value.map((p) => p.longitude).reduce((a, b) => a + b) / e.value.length,
        ),
    };
  }

  LatLng _effectivePos(MapPin p, Map<String, LatLng> centroids) {
    final rid = p.regionId;
    return rid == null ? p.position : (centroids[rid] ?? p.position);
  }

  Marker _markerAt(LatLng point, MapPin p) => Marker(
        point: point,
        width: p.size,
        height: p.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: p.onTap,
          child: Tooltip(message: p.label, child: _PinIcon(pin: p)),
        ),
      );

  List<Marker> _pinMarkers() {
    final c = _centroids;
    return widget.pins.map((p) => _markerAt(_effectivePos(p, c), p)).toList();
  }

  /// The pin layer(s) for the current view:
  ///  * plain markers when clustering is off (or too few pins);
  ///  * count badges when zoomed far out;
  ///  * repulsed (displaced) markers otherwise, so overlapping pins each
  ///    stay individually visible with their status colour.
  List<Widget> _pinLayers() {
    if (!widget.cluster || widget.pins.length < 2) {
      return [MarkerLayer(markers: _pinMarkers())];
    }
    final MapCamera cam;
    final double zoom;
    try {
      cam = _controller.camera;
      zoom = cam.zoom;
    } catch (_) {
      // Camera not laid out yet — the post-frame callback rebuilds.
      return [MarkerLayer(markers: _pinMarkers())];
    }

    if (zoom < _clusterBelowZoom) {
      return [
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(36, 36),
            spiderfyCluster: true,
            spiderfySpiralDistanceMultiplier: 3,
            padding: const EdgeInsets.all(50),
            markers: _pinMarkers(),
            builder: (context, markers) => _ClusterBadge(count: markers.length),
          ),
        ),
      ];
    }

    final d = _declutter(cam);
    return [
      if (d.connectors.isNotEmpty) PolylineLayer(polylines: d.connectors),
      MarkerLayer(markers: d.markers),
    ];
  }

  /// Repulses overlapping pins apart in screen space (at the current
  /// zoom), then projects back to coordinates. Returns the displaced
  /// markers plus thin connectors from each moved pin to its true spot.
  ({List<Marker> markers, List<Polyline> connectors}) _declutter(
      MapCamera cam) {
    final pins = widget.pins;
    final centroids = _centroids;
    final base = pins.map((p) => _effectivePos(p, centroids)).toList();
    final origin = <Offset>[];
    for (final b in base) {
      final pt = cam.latLngToScreenPoint(b);
      origin.add(Offset(pt.x, pt.y));
    }
    final sizes = pins.map((p) => p.size).toList();
    final placed = _relax(origin, sizes);

    final markers = <Marker>[];
    final connectors = <Polyline>[];
    for (var i = 0; i < pins.length; i++) {
      final here = cam.pointToLatLng(Point(placed[i].dx, placed[i].dy));
      if ((placed[i] - origin[i]).distance > 10) {
        connectors.add(Polyline(
          points: [base[i], here],
          color: Colors.black.withValues(alpha: 0.25),
          strokeWidth: 1,
        ));
      }
      markers.add(_markerAt(here, pins[i]));
    }
    return (markers: markers, connectors: connectors);
  }

  // Iterative pairwise separation: pins closer than half their combined
  // sizes (plus a gap) push apart until they clear or we hit the cap.
  List<Offset> _relax(List<Offset> points, List<double> sizes) {
    final out = List<Offset>.from(points);
    const gap = 4.0;
    const iterations = 16;
    for (var it = 0; it < iterations; it++) {
      var moved = false;
      for (var i = 0; i < out.length; i++) {
        for (var j = i + 1; j < out.length; j++) {
          final delta = out[j] - out[i];
          var dist = delta.distance;
          final minDist = (sizes[i] + sizes[j]) / 2 + gap;
          if (dist >= minDist) continue;
          moved = true;
          // Exact overlap → deterministic angle from the index so the
          // split is stable across rebuilds (no random jitter).
          final Offset dir;
          if (dist < 0.01) {
            dir = Offset(cos(i * 2.399963), sin(i * 2.399963));
            dist = 0.01;
          } else {
            dir = delta / dist;
          }
          final push = (minDist - dist) / 2;
          out[i] = out[i] - dir * push;
          out[j] = out[j] + dir * push;
        }
      }
      if (!moved) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final remembered = _remembered;
    final map = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        // A remembered camera wins; otherwise fit to the pins. (When
        // initialCameraFit is non-null it overrides initialCenter/Zoom.)
        initialCenter: remembered?.center ?? const LatLng(49.8951, -97.1384),
        initialZoom: remembered?.zoom ?? 15,
        initialCameraFit: remembered == null ? _fit() : null,
        onPositionChanged: _onPositionChanged,
        interactionOptions: InteractionOptions(flags: _interactiveFlags()),
      ),
      children: [
        landgrabTileLayer(context),
        // Faint GPS-uncertainty circles under the pins (poles only, and
        // only when accuracy is good enough to be meaningful). Neutral
        // grey so it doesn't fight the status-coloured pins.
        if (_accuracyCircles.isNotEmpty)
          CircleLayer(circles: _accuracyCircles),
        if (widget.polygon != null || _stroke.isNotEmpty)
          PolygonLayer(polygons: [
            Polygon(
              points: _stroke.isNotEmpty ? _stroke : widget.polygon!,
              color: Colors.purple.withValues(alpha: 0.15),
              borderColor: Colors.purple,
              borderStrokeWidth: 2,
              isFilled: true,
            ),
          ]),
        ..._pinLayers(),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 20,
                height: 20,
                child: const _UserLocationDot(),
              ),
            ],
          ),
        const Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(right: 4, bottom: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xBFFFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '© CartoDB · © OpenStreetMap',
                  style: TextStyle(fontSize: 10, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
        if (widget.interactive && !widget.drawMode)
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Locate me',
                onPressed: _locating ? null : _locateMe,
                child: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),
      ],
    );

    if (!widget.drawMode) return map;

    // Draw mode: a passive Listener records single-finger strokes
    // without claiming the arena, so the map's two-finger pinch/zoom
    // still works underneath.
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      child: map,
    );
  }
}

/// Renders a [MapPin] either as a filled circular badge (poles /
/// puzzlets) or a bare icon (bathrooms / regions), per `pin.filled`.
class _PinIcon extends StatelessWidget {
  final MapPin pin;
  const _PinIcon({required this.pin});

  @override
  Widget build(BuildContext context) {
    final Widget base = !pin.filled
        ? Icon(pin.icon, color: pin.color, size: pin.size)
        : Container(
            width: pin.size,
            height: pin.size,
            decoration: BoxDecoration(
              color: pin.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(pin.icon, color: Colors.white, size: pin.size * 0.55),
          );

    final overlays = <Widget>[];

    if (pin.starred) {
      // Validator-only badge, hung just outside the top-right so it
      // doesn't cover the pin's glyph. Matches the author scouting map.
      overlays.add(const Positioned(
        right: -2,
        top: -2,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Padding(
            padding: EdgeInsets.all(1),
            child: Icon(Icons.star, size: 12, color: Colors.amber),
          ),
        ),
      ));
    }

    if (pin.difficulty != null) {
      // Difficulty in tiny numerals at the bottom-right edge of the circle
      // — opposite the star, so a validator-only pin can show both.
      overlays.add(Positioned(
        right: -3,
        bottom: -3,
        child: Container(
          constraints: const BoxConstraints(minWidth: 12),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: pin.color, width: 1),
          ),
          child: Text(
            '${pin.difficulty}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ));
    }

    if (overlays.isEmpty) return base;
    return Stack(
      clipBehavior: Clip.none,
      children: [base, ...overlays],
    );
  }
}

/// Count badge shown when overlapping pins collapse into a cluster.
/// Neutral dark circle so it reads as "N things here", distinct from the
/// status-coloured pins.
class _ClusterBadge extends StatelessWidget {
  final int count;
  const _ClusterBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
