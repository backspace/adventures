class Region {
  final String id;
  final String name;
  final String? description;
  Region? parentRegion;

  Region(
      {required this.id,
      required this.name,
      this.description,
      this.parentRegion});

  factory Region.fromJson(Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    Region region = Region(
      id: json['id'],
      name: attributes['name'],
      description: attributes['description'],
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
