import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Live user-location layer. Subscribes to [Geolocator.getPositionStream]
/// on mount, cancels on unmount, and renders:
///
///   * A dashed accuracy circle (via [CircleLayer]) whose radius
///     scales with GPS-reported accuracy.
///   * A blue dot at the current position.
///   * A translucent "cone of view" pointing along the movement
///     heading, but ONLY while moving above [_movingSpeedThreshold]
///     — below that GPS heading is noise and the cone would spin
///     randomly. Compass heading (magnetometer) would give a heading
///     while stationary, but the equivalent flutter_map_location_marker
///     plugin conflicts with our current geolocator / flutter_map
///     versions, and the movement-only cone is genuinely useful in a
///     walking game while adding no dependencies.
///
/// The layer emits each fresh fix through [onPosition] so the parent
/// can drive its "Locate me" behaviour off the same stream — no need
/// for a separate one-shot Geolocator call when the button is tapped.
class LiveLocationLayer extends StatefulWidget {
  final ValueChanged<Position>? onPosition;
  final double distanceFilterM;

  const LiveLocationLayer({
    super.key,
    this.onPosition,
    this.distanceFilterM = 3,
  });

  @override
  State<LiveLocationLayer> createState() => _LiveLocationLayerState();
}

class _LiveLocationLayerState extends State<LiveLocationLayer> {
  static const double _movingSpeedThreshold = 0.7; // m/s ≈ slow walk
  static const double _maxAccuracyForCircle = 200;

  StreamSubscription<Position>? _sub;
  Position? _position;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // Kick off with a single high-accuracy fix so the marker appears
    // immediately instead of waiting for the first stream event.
    try {
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      _emit(initial);
    } catch (_) {
      // Non-fatal: the stream below will still deliver fixes.
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        // Only emit when the user has moved this far since the last
        // fix. Cuts noise while stationary and saves battery.
        distanceFilter: widget.distanceFilterM.round(),
      ),
    ).listen((p) {
      if (!mounted) return;
      _emit(p);
    });
  }

  void _emit(Position p) {
    setState(() => _position = p);
    widget.onPosition?.call(p);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    if (p == null) return const SizedBox.shrink();
    final latLng = LatLng(p.latitude, p.longitude);
    final showCone = p.speed >= _movingSpeedThreshold && !p.heading.isNaN;
    return Stack(children: [
      // Accuracy circle. `useRadiusInMeter: true` makes the circle
      // shrink/grow correctly with zoom — a 30 m accuracy circle
      // stays 30 m on the ground regardless of camera scale.
      if (p.accuracy > 0 && p.accuracy <= _maxAccuracyForCircle)
        CircleLayer(circles: [
          CircleMarker(
            point: latLng,
            radius: p.accuracy,
            useRadiusInMeter: true,
            color: Colors.blue.withValues(alpha: 0.10),
            borderColor: Colors.blue.withValues(alpha: 0.35),
            borderStrokeWidth: 1,
          ),
        ]),
      MarkerLayer(markers: [
        Marker(
          point: latLng,
          width: 48,
          height: 48,
          child: _LiveLocationMarker(
            headingDegrees: showCone ? p.heading : null,
          ),
        ),
      ]),
    ]);
  }
}

class _LiveLocationMarker extends StatelessWidget {
  final double? headingDegrees;
  const _LiveLocationMarker({required this.headingDegrees});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LiveLocationPainter(headingDegrees: headingDegrees),
    );
  }
}

class _LiveLocationPainter extends CustomPainter {
  final double? headingDegrees;
  _LiveLocationPainter({required this.headingDegrees});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final dotRadius = 8.0;

    // Cone first so the dot sits on top of it.
    final heading = headingDegrees;
    if (heading != null) {
      // Cone points along +Y in local space, then we rotate. Rotate
      // around the dot centre so the cone appears to swivel around
      // the user pin, not the marker's top-left corner.
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      // heading is degrees clockwise from true north; canvas rotate
      // is radians clockwise from +X. Add π to point "up" (north)
      // by default, then heading in radians.
      final rad = heading * math.pi / 180;
      canvas.rotate(rad);
      final coneLength = 24.0;
      final coneHalfWidth = 12.0;
      final conePath = ui.Path()
        ..moveTo(-coneHalfWidth, 0)
        ..lineTo(coneHalfWidth, 0)
        ..lineTo(0, -coneLength)
        ..close();
      canvas.drawPath(
        conePath,
        Paint()
          ..shader = _coneShader(coneLength)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    // Dot with a soft outer ring for legibility on light basemaps.
    canvas.drawCircle(
      centre,
      dotRadius + 3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      centre,
      dotRadius,
      Paint()..color = Colors.blue.shade600,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveLocationPainter oldDelegate) {
    return oldDelegate.headingDegrees != headingDegrees;
  }

  /// Fade the cone from opaque near the dot to transparent at the
  /// tip so it reads as a "beam" rather than a solid arrow.
  Shader _coneShader(double length) {
    return const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0x66418AFB),
        Color(0x00418AFB),
      ],
    ).createShader(Rect.fromLTWH(-16, -length, 32, length));
  }
}
