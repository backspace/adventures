import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/services/location_service.dart';
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
class PinMap extends StatefulWidget {
  final List<MapPin> pins;
  final bool interactive;
  final bool drawMode;
  final void Function(List<LatLng> polygon)? onPolygonDrawn;
  final List<LatLng>? polygon;

  const PinMap({
    super.key,
    required this.pins,
    this.interactive = true,
    this.drawMode = false,
    this.onPolygonDrawn,
    this.polygon,
  });

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  final MapController _controller = MapController();
  LatLng? _userLocation;
  bool _locating = false;

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

  @override
  void didUpdateWidget(PinMap oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      return widget.pins.any((p) => !bounds.contains(p.position));
    } catch (_) {
      return false;
    }
  }

  CameraFit _fit() {
    if (widget.pins.length <= 1) {
      final position = widget.pins.isEmpty
          ? const LatLng(49.8951, -97.1384)
          : widget.pins.single.position;
      return CameraFit.coordinates(coordinates: [position], maxZoom: 17);
    }
    return CameraFit.coordinates(
      coordinates: widget.pins.map((p) => p.position).toList(),
      padding: const EdgeInsets.all(40),
      maxZoom: 17,
    );
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final fix = await LocationService.getCurrent();
      final me = LatLng(fix.latitude, fix.longitude);
      final zoom = max(_controller.camera.zoom, 15.0);
      _controller.move(me, zoom);
      if (!mounted) return;
      setState(() => _userLocation = me);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
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

  @override
  Widget build(BuildContext context) {
    final map = FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCameraFit: _fit(),
        interactionOptions: InteractionOptions(flags: _interactiveFlags()),
      ),
      children: [
        landgrabTileLayer(context),
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
        MarkerLayer(
          markers: widget.pins
              .map((p) => Marker(
                    point: p.position,
                    width: p.size,
                    height: p.size,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: p.onTap,
                      child: Tooltip(
                        message: p.label,
                        child: _PinIcon(pin: p),
                      ),
                    ),
                  ))
              .toList(),
        ),
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
    if (!pin.filled) {
      return Icon(pin.icon, color: pin.color, size: pin.size);
    }
    return Container(
      width: pin.size,
      height: pin.size,
      decoration: BoxDecoration(
        color: pin.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Icon(pin.icon, color: Colors.white, size: pin.size * 0.55),
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
