import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/services/location_service.dart';

/// What the caller gets back from [AdjustPositionRoute]: the chosen pin
/// [position] plus the GPS [fix] that was in play (possibly reacquired
/// on this screen). The caller computes the manual offset as the
/// distance between the two.
class AdjustPositionResult {
  final LatLng position;
  final LocationFix fix;

  const AdjustPositionResult({required this.position, required this.fix});
}

/// A full-screen map for manually placing a pole's marker. GPS often
/// lands the pin somewhere the author has to physically walk toward
/// before it settles; here they can just drag it to the true spot
/// instead. Dragging the pin moves it; dragging anywhere else pans the
/// map as usual. "Reacquire GPS" takes a fresh reading and snaps the
/// pin back to it (a clean baseline). A faint line shows how far the
/// pin has been moved from the current GPS point.
class AdjustPositionRoute extends StatefulWidget {
  final LatLng initialPosition;
  final LocationFix gpsFix;
  final String title;

  const AdjustPositionRoute({
    super.key,
    required this.initialPosition,
    required this.gpsFix,
    this.title = 'Adjust position',
  });

  @override
  State<AdjustPositionRoute> createState() => _AdjustPositionRouteState();
}

class _AdjustPositionRouteState extends State<AdjustPositionRoute> {
  final MapController _controller = MapController();
  final Distance _distance = const Distance();

  late LatLng _pin;
  late LocationFix _fix;
  bool _busy = false;

  // The pin is an overlay ABOVE the map (not a map marker) so its own
  // gesture wins on iOS — a marker's onPan loses the arena to the map's
  // scale recognizer. We reposition it from the camera whenever the map
  // moves.
  StreamSubscription<MapEvent>? _mapEvents;

  // Screen-space anchor tracked during a pin drag. The camera stays put
  // while we own the pointer, so accumulating deltas and unprojecting
  // each frame keeps the pin under the finger.
  Offset? _dragAnchor;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPosition;
    _fix = widget.gpsFix;
    _mapEvents = _controller.mapEventStream.listen((_) {
      // Map panned/zoomed → the pin's screen position changed. Skip
      // while dragging the pin (the camera isn't moving then anyway).
      if (mounted && _dragAnchor == null) setState(() {});
    });
    // First layout: the camera isn't ready during initState, so nudge a
    // rebuild once it is, to place the overlay pin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mapEvents?.cancel();
    super.dispose();
  }

  LatLng get _gpsPoint => LatLng(_fix.latitude, _fix.longitude);

  /// Screen position of a coordinate, or null if the camera isn't laid
  /// out yet.
  Offset? _screenOf(LatLng ll) {
    try {
      final p = _controller.camera.latLngToScreenPoint(ll);
      return Offset(p.x, p.y);
    } catch (_) {
      return null;
    }
  }

  double get _offsetM => _distance.as(LengthUnit.Meter, _gpsPoint, _pin);

  void _onPanStart(DragStartDetails d) {
    _dragAnchor = _screenOf(_pin);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final next = anchor + d.delta;
    try {
      final ll = _controller.camera.pointToLatLng(math.Point(next.dx, next.dy));
      setState(() {
        _dragAnchor = next;
        _pin = ll;
      });
    } catch (_) {
      // Camera not ready; ignore this frame.
    }
  }

  void _onPanEnd(DragEndDetails d) => _dragAnchor = null;

  Future<void> _reacquire() async {
    setState(() => _busy = true);
    try {
      final fix = await LocationService.getCurrent();
      if (!mounted) return;
      final me = LatLng(fix.latitude, fix.longitude);
      setState(() {
        _fix = fix;
        // Fresh reading = fresh baseline: snap the pin back onto it.
        _pin = me;
        _busy = false;
      });
      final zoom = math.max(_controller.camera.zoom, 18.0);
      _controller.move(me, zoom);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      AdjustPositionResult(position: _pin, fix: _fix),
    );
  }

  // A 56px touch target so the pin is easy to grab. The visual pin's
  // tip is at the box's bottom-centre, so we offset the box up and left
  // to sit that tip on the coordinate.
  static const double _pinBox = 56;

  Widget _pinOverlay(ThemeData theme) {
    final sp = _screenOf(_pin);
    if (sp == null) return const SizedBox.shrink();
    return Positioned(
      left: sp.dx - _pinBox / 2,
      top: sp.dy - _pinBox,
      width: _pinBox,
      height: _pinBox,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Icon(
            Icons.location_on,
            size: 44,
            color: theme.colorScheme.primary,
            shadows: const [
              Shadow(color: Colors.black45, blurRadius: 3),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moved = _offsetM >= 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _reacquire,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: const Text('Reacquire GPS'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.initialPosition,
                    initialZoom: 18,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      retinaMode: RetinaMode.isHighDensity(context),
                      userAgentPackageName: 'ca.chromatin.poles',
                    ),
                    if (moved)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: [_gpsPoint, _pin],
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.6),
                          strokeWidth: 2,
                        ),
                      ]),
                    // GPS reading — a small muted dot the pin was dragged from.
                    MarkerLayer(markers: [
                      Marker(
                        point: _gpsPoint,
                        width: 16,
                        height: 16,
                        child: const _GpsDot(),
                      ),
                    ]),
                    const Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4, bottom: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xBFFFFFFF),
                            borderRadius:
                                BorderRadius.all(Radius.circular(4)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text(
                              '© CartoDB · © OpenStreetMap',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Draggable pin as an overlay ABOVE the map. Being a
                // sibling on top, it hit-tests first, so a drag starting
                // on it is claimed here and never reaches the map — while
                // drags elsewhere still pan the map. The icon's tip
                // (bottom-centre) sits on the coordinate.
                _pinOverlay(theme),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    moved
                        ? 'Drag the pin to the pole. Moved ${_offsetM.toStringAsFixed(0)} m from GPS.'
                        : 'Drag the pin to where the pole really is.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Use this location'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsDot extends StatelessWidget {
  const _GpsDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade400,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
