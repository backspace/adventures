import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

String getRegionPath(Incarnation incarnation) {
  List<String> regionNames = [];
  Region? currentRegion = incarnation.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}
