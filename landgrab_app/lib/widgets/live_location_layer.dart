import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/widgets/location_rationale.dart';
import 'package:latlong2/latlong.dart';

/// Live user-location layer. Subscribes to [Geolocator.getPositionStream]
/// on mount, cancels on unmount, and renders:
///
///   * A dashed accuracy circle (via [CircleLayer]) whose radius
///     scales with GPS-reported accuracy.
///   * A blue dot at the current position.
///   * A translucent "cone of view" pointing along the effective
///     heading. Above [_movingSpeedThreshold] we trust GPS heading
///     (accurate while walking); below it we fall back to the phone
///     compass so you still see which way you're facing while
///     stationary. Falling back only while slow avoids the compass's
///     tendency to jitter versus GPS's smoothed direction of travel.
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

class _LiveLocationLayerState extends State<LiveLocationLayer>
    with WidgetsBindingObserver {
  static const double _movingSpeedThreshold = 0.7; // m/s ≈ slow walk
  static const double _maxAccuracyForCircle = 200;

  StreamSubscription<Position>? _sub;
  StreamSubscription<CompassEvent>? _compassSub;
  Position? _position;
  double? _compassHeading;
  // Set when the geolocator stream last errored (typically iOS's
  // kCLErrorDomain=1 when the screen locks). We resubscribe on the
  // next foreground resume rather than in the error handler itself,
  // because restarting mid-lock would just error again.
  bool _positionStreamNeedsRestart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    _startCompass();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _positionStreamNeedsRestart) {
      _positionStreamNeedsRestart = false;
      _restartPositionStream();
    }
  }

  void _restartPositionStream() {
    _sub?.cancel();
    _sub = null;
    _startPositionStream();
  }

  void _startCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) return; // No sensor (e.g. iOS simulator, some tablets).
    _compassSub = stream.listen(
      (event) {
        if (!mounted) return;
        final heading = event.heading;
        if (heading == null) return;
        final previous = _compassHeading;
        // Sensor fires many times per second; only rebuild when the
        // heading has actually rotated visibly. The cone renders at
        // integer-degree granularity so sub-degree jitter never
        // reaches the screen anyway.
        if (previous != null && (heading - previous).abs() < 1.5) return;
        setState(() => _compassHeading = heading);
      },
      // Silently ignore sensor errors — the marker still renders
      // usefully without a heading, and there's no UI recovery step.
      onError: (_, __) {},
    );
  }

  Future<void> _start() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Passive trigger: ask at most once ever. If we've already asked
      // (whatever the outcome), stay quiet rather than nagging on every map
      // load — a user-initiated "locate me" / capture tap can still re-ask.
      if (await UiPreferences.getLocationAutoAsked()) return;
      await UiPreferences.setLocationAutoAsked(true);
      // Explain why before the OS prompt; if the player declines the
      // pre-prompt, don't trigger the system dialog at all.
      if (!mounted) return;
      if (!await LocationRationale.show(context)) return;
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

    _startPositionStream();
  }

  void _startPositionStream() {
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        // Only emit when the user has moved this far since the last
        // fix. Cuts noise while stationary and saves battery.
        distanceFilter: widget.distanceFilterM.round(),
      ),
    ).listen(
      (p) {
        if (!mounted) return;
        _emit(p);
      },
      // iOS surfaces kCLErrorDomain=1 (~"denied") when the screen
      // locks or the app is backgrounded, even when permission is
      // fine — the stream just gets torn down. Without an onError
      // this bubbles as an unhandled exception and crashes the app.
      // Mark for restart on next foreground resume and swallow.
      onError: (error, stackTrace) {
        _positionStreamNeedsRestart = true;
      },
      cancelOnError: true,
    );
  }

  void _emit(Position p) {
    setState(() => _position = p);
    widget.onPosition?.call(p);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    if (p == null) return const SizedBox.shrink();
    final latLng = LatLng(p.latitude, p.longitude);
    // While walking above the threshold, GPS heading is smoothed and
    // reliable. While stationary or drifting, GPS heading is noise;
    // fall back to the compass (device orientation) so the cone
    // still shows which way the user is facing.
    final double? effectiveHeading;
    if (p.speed >= _movingSpeedThreshold && !p.heading.isNaN) {
      effectiveHeading = p.heading;
    } else {
      effectiveHeading = _compassHeading;
    }
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
          // Sized to fit the heading cone without clipping — the cone
          // reaches _coneLength out from the centred dot, so the box needs
          // to be at least twice that on a side. The extra space is
          // transparent (and the marker isn't interactive), so a roomy box
          // costs nothing.
          point: latLng,
          width: 96,
          height: 96,
          child: _LiveLocationMarker(headingDegrees: effectiveHeading),
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

  // Heading cone geometry. Kept larger than the dot so the direction the
  // player is facing reads clearly at a glance.
  static const double _coneLength = 40;
  static const double _coneHalfWidth = 10;

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
      final conePath = ui.Path()
        ..moveTo(-_coneHalfWidth, 0)
        ..lineTo(_coneHalfWidth, 0)
        ..lineTo(0, -_coneLength)
        ..close();
      canvas.drawPath(
        conePath,
        Paint()
          ..shader = _coneShader(_coneLength)
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
    ).createShader(
        Rect.fromLTWH(-_coneHalfWidth, -length, _coneHalfWidth * 2, length));
  }
}
