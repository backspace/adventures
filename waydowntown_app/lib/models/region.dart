class Region {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double? distance;
  Region? parentRegion;
  List<Region> children = [];

  Region({
    required this.id,
    required this.name,
    this.description,
    this.parentRegion,
    this.latitude,
    this.longitude,
    this.distance,
  });

  factory Region.fromJson(Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    Region region = Region(
      id: json['id'],
      name: attributes['name'],
      description: attributes['description'],
      latitude: attributes['latitude'] != null
          ? double.parse(attributes['latitude'])
          : null,
      longitude: attributes['longitude'] != null
          ? double.parse(attributes['longitude'])
          : null,
      distance: attributes['distance']?.toDouble(),
    );

    if (relationships != null &&
        relationships['parent'] != null &&
        relationships['parent']['data'] != null) {
      final parentData = relationships['parent']['data'];
      final parentJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == parentData['id'],
        orElse: () => <String, Object>{},
      );

      if (parentJson != null) {
        region.parentRegion = Region.fromJson(parentJson, included);
      }
    }

    return region;
  }

  static List<Region> parseRegions(Map<String, dynamic> apiResponse) {
    final List<dynamic> data = apiResponse['data'];
    final List<dynamic> included = apiResponse['included'] ?? [];

    Map<String, Region> regionMap = {};

    // Extract all regions
    for (var item in [...data, ...included]) {
      if (item['type'] == 'regions') {
        Region region = Region.fromJson(item, included);
        regionMap[region.id] = region;
      }
    }

    // Nest children
    for (var item in [...data, ...included]) {
      if (item['type'] == 'regions' && item['relationships'] != null) {
        var relationships = item['relationships'];
        if (relationships['parent'] != null &&
            relationships['parent']['data'] != null) {
          String parentId = relationships['parent']['data']['id'];
          Region? parentRegion = regionMap[parentId];
          Region? childRegion = regionMap[item['id']];
          if (parentRegion != null && childRegion != null) {
            childRegion.parentRegion = parentRegion;
            parentRegion.children.add(childRegion);
          }
        }
      }
    }

    // Return only root regions
    return regionMap.values
        .where((region) => region.parentRegion == null)
        .toList();
  }

  static void sortAlphabetically(List<Region> regions) {
    regions
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (var region in regions) {
      if (region.children.isNotEmpty) {
        sortAlphabetically(region.children);
      }
    }
  }
}
