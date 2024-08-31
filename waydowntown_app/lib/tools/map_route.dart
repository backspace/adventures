import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:waydowntown/widgets/game_map.dart';

class MapRoute extends StatefulWidget {
  const MapRoute({super.key});

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: const Stack(
        children: [
          GameMap(
            centre: LatLng(49.891725, -97.143130),
            markers: [],
          ),
        ],
      ),
    );
  }
}
