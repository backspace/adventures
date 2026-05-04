import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/widgets/full_screen_map.dart';
import 'package:poles/widgets/map_pin.dart';
import 'package:poles/widgets/pin_map.dart';

/// A small embedded map showing one location. Tap the expand icon to push a
/// full-screen view of the same point.
class MiniLocationMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String label;
  final double height;

  const MiniLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label = 'Captured location',
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final pin = MapPin(
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
