import 'package:flutter/material.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

class LocationHeader extends StatelessWidget {
  final Game game;

  const LocationHeader({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        getRegionPath(game.incarnation),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

String getRegionPath(Incarnation incarnation) {
  List<String> regionNames = [];
  Region? currentRegion = incarnation.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}
