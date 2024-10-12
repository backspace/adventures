class Region {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  Region? parentRegion;
  List<Region> children = [];

  Region({
    required this.id,
    required this.name,
    this.description,
    this.parentRegion,
    this.latitude,
    this.longitude,
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
    );

    if (relationships != null &&
        relationships['parent'] != null &&
        relationships['parent']['data'] != null) {
      final parentData = relationships['parent']['data'];
      final parentJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == parentData['id'],
        orElse: () => null,
      );
      if (parentJson != null) {
        region.parentRegion = Region.fromJson(parentJson, included);
      }
    }

    return region;
  }

  static List<Region> parseRegions(Map<String, dynamic> apiResponse) {
    final List<dynamic> data = apiResponse['data'];

    Map<String, Region> regionMap = {};

    // Extract all regions
    for (var item in data) {
      if (item['type'] == 'regions') {
        Region region = Region.fromJson(item, []);
        regionMap[region.id] = region;
      }
    }

    // Nest children
    for (var item in data) {
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
}
