import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/widgets/full_screen_map.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/pin_map.dart';

/// A small embedded map showing one location. Tap the expand icon to push a
/// full-screen view of the same point.
class MiniLocationMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String label;
  final double height;

  /// Pre-built pin to render. Null means the default plain
  /// [Icons.location_on] pin in the theme's primary colour; the
  /// [MiniLocationMap.pole] constructor supplies a typed pole pin instead.
  final MapPin? _pin;

  const MiniLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label = 'Captured location',
    this.height = 160,
  }) : _pin = null;

  /// Renders the same barcode-in-a-filled-circle marker (with GPS-accuracy
  /// ring) that the supervisor/validator/author maps use via [MapPin.pole],
  /// so a pole's embedded map reads consistently with the full maps.
  MiniLocationMap.pole({
    Key? key,
    required double latitude,
    required double longitude,
    required String label,
    required Color color,
    double? accuracyM,
    double height = 160,
  }) : this._withPin(
          key: key,
          latitude: latitude,
          longitude: longitude,
          label: label,
          height: height,
          pin: MapPin.pole(
            position: LatLng(latitude, longitude),
            label: label,
            color: color,
            accuracyM: accuracyM,
          ),
        );

  const MiniLocationMap._withPin({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.height,
    required MapPin pin,
  }) : _pin = pin;

  @override
  Widget build(BuildContext context) {
    final pin = _pin ??
        MapPin(
          position: LatLng(latitude, longitude),
          label: label,
          icon: Icons.location_on,
          color: Theme.of(context).colorScheme.primary,
        );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(child: PinMap(pins: [pin], interactive: false)),
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                child: IconButton(
                  iconSize: 20,
                  tooltip: 'Expand',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenMap(title: label, pins: [pin]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
