import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/models/bathroom.dart';

class MapPin {
  final LatLng position;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  /// Icon size in logical pixels. Bathroom pins (and other secondary
  /// markers) pass a smaller value so they don't compete with poles.
  final double size;

  /// When true the pin renders as a filled circle in [color] with a
  /// white glyph inside (a compact "badge"), rather than a bare icon.
  /// Poles and puzzlets use this so they read as small coloured dots
  /// with a type glyph; bathrooms/regions keep the plain-icon look.
  final bool filled;

  /// GPS uncertainty (metres) to draw as a faint circle around the pin,
  /// so authors/validators/supervisors can see how confident the
  /// recorded position is. Null (the default) draws no circle; only
  /// pole pins set it.
  final double? accuracyM;

  const MapPin({
    required this.position,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 36,
    this.filled = false,
    this.accuracyM,
  });

  /// Standard pole marker: a barcode glyph in a filled circle.
  factory MapPin.pole({
    required LatLng position,
    required String label,
    required Color color,
    VoidCallback? onTap,
    double? accuracyM,
  }) =>
      MapPin(
        position: position,
        label: label,
        icon: Icons.barcode_reader,
        color: color,
        onTap: onTap,
        size: _typedPinSize,
        filled: true,
        accuracyM: accuracyM,
      );

  /// Standard puzzlet marker: a question mark in a filled circle.
  factory MapPin.puzzlet({
    required LatLng position,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) =>
      MapPin(
        position: position,
        label: label,
        icon: Icons.question_mark,
        color: color,
        onTap: onTap,
        size: _typedPinSize,
        filled: true,
      );

  // Poles/puzzlets sit smaller than the old 36 bare pins so a dense
  // map stays legible.
  static const double _typedPinSize = 26;
}

/// Standardised bathroom marker — muted, smaller, distinct icon so it
/// doesn't compete with poles/puzzlets/regions for the player's
/// attention.
MapPin bathroomPin(Bathroom b, {VoidCallback? onTap}) {
  return MapPin(
    position: LatLng(b.latitude, b.longitude),
    label: b.displayName(),
    icon: Icons.wash,
    color: Colors.blueGrey.shade400,
    size: 24,
    onTap: onTap,
  );
}
