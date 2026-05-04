import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/widgets/map_pin.dart';

/// Shared FlutterMap configuration: CartoDB Positron tiles, attribution, and
/// a marker layer. Used for both mini-thumbnails and full-screen views.
class PinMap extends StatelessWidget {
  final List<MapPin> pins;
  final bool interactive;

  const PinMap({super.key, required this.pins, this.interactive = true});

  CameraFit _fit() {
    if (pins.length <= 1) {
      final position = pins.isEmpty
          ? const LatLng(49.8951, -97.1384)
          : pins.single.position;
      return CameraFit.coordinates(coordinates: [position], maxZoom: 17);
    }
    return CameraFit.coordinates(
      coordinates: pins.map((p) => p.position).toList(),
      padding: const EdgeInsets.all(40),
      maxZoom: 17,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: _fit(),
        interactionOptions: interactive
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
          markers: pins
              .map((p) => Marker(
                    point: p.position,
                    width: 36,
                    height: 36,
                    child: Tooltip(
                      message: p.label,
                      child: Icon(p.icon, color: p.color, size: 36),
                    ),
                  ))
              .toList(),
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
      ],
    );
  }
}
