import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MapPin {
  final LatLng position;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const MapPin({
    required this.position,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });
}
