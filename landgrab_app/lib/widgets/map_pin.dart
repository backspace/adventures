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
  /// Poles, puzzlets, and bathrooms use this so they read as one family
  /// of small coloured dots with a type glyph; regions keep the
  /// plain-icon look.
  final bool filled;

  /// GPS uncertainty (metres) to draw as a faint circle around the pin,
  /// so authors/validators/supervisors can see how confident the
  /// recorded position is. Null (the default) draws no circle; only
  /// pole pins set it.
  final double? accuracyM;

  /// Pins sharing a [regionId] are plotted around the region's centroid
  /// (see [PinMap]) rather than their individual — often noisy, GPS-in-a-
  /// building — positions. Only region-assigned puzzlets set it.
  final String? regionId;

  /// Overlays a small amber star badge — marks validator-only puzzlets,
  /// which are hidden from players and set aside from validation work.
  final bool starred;

  /// Puzzlet difficulty (1–10), shown as a tiny numeral badge at the edge
  /// of the pin. Null when not annotated (poles, and maps that don't
  /// surface difficulty).
  final int? difficulty;

  const MapPin({
    required this.position,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 36,
    this.filled = false,
    this.accuracyM,
    this.regionId,
    this.starred = false,
    this.difficulty,
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
    String? regionId,
    bool starred = false,
    int? difficulty,
  }) =>
      MapPin(
        position: position,
        label: label,
        icon: Icons.question_mark,
        color: color,
        onTap: onTap,
        size: _typedPinSize,
        filled: true,
        regionId: regionId,
        starred: starred,
        difficulty: difficulty,
      );

  // Poles/puzzlets sit smaller than the old 36 bare pins so a dense
  // map stays legible.
  static const double _typedPinSize = 26;
}

/// Standardised bathroom marker — a filled circular badge like poles and
/// puzzlets (so all markers read as one family), but in a muted blue-grey
/// with a distinct glyph so it doesn't compete for the player's attention.
MapPin bathroomPin(Bathroom b, {VoidCallback? onTap}) {
  return MapPin(
    position: LatLng(b.latitude, b.longitude),
    label: b.displayName(),
    icon: Icons.wash,
    color: Colors.blueGrey.shade600,
    size: MapPin._typedPinSize,
    filled: true,
    onTap: onTap,
  );
}
