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

  const MapPin({
    required this.position,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.size = 36,
  });
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
