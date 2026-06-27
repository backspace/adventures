import 'package:flutter/material.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/pin_map.dart';

class FullScreenMap extends StatelessWidget {
  final String title;
  final List<MapPin> pins;

  const FullScreenMap({super.key, required this.title, required this.pins});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PinMap(pins: pins),
    );
  }
}
