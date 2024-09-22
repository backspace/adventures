import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/specification.dart';

String getRegionPath(Specification specification) {
  List<String> regionNames = [];
  Region? currentRegion = specification.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}
