import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/map_pin.dart';

/// Shared FlutterMap configuration: CartoDB Positron tiles, attribution, and
/// a marker layer. Used for both mini-thumbnails and full-screen views.
class PinMap extends StatefulWidget {
  final List<MapPin> pins;
  final bool interactive;

  const PinMap({super.key, required this.pins, this.interactive = true});

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  final MapController _controller = MapController();
  LatLng? _userLocation;
  bool _locating = false;

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

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCameraFit: _fit(),
        interactionOptions: widget.interactive
            ? const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate)
            : const InteractionOptions(flags: InteractiveFlag.none),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'ca.chromatin.poles',
        ),
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
                        child: Icon(p.icon, color: p.color, size: p.size),
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
        if (widget.interactive)
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
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
