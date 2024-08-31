class Region {
  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  Region? parentRegion;

  Region(
      {required this.id,
      required this.name,
      this.description,
      this.parentRegion,
      this.latitude,
      this.longitude});

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
}
