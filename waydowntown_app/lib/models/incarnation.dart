import 'package:waydowntown/models/region.dart';

class Incarnation {
  final String id;
  final String concept;
  final String mask;
  final Region? region;
  final bool placed;

  const Incarnation({
    required this.id,
    required this.concept,
    required this.mask,
    this.region,
    required this.placed,
  });

  factory Incarnation.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    Region? region;
    if (attributes['placed'] == true) {
      if (relationships == null ||
          relationships['region'] == null ||
          relationships['region']['data'] == null) {
        throw const FormatException('Placed incarnation must have a region');
      }

      final regionData = relationships['region']['data'];
      final regionJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == regionData['id'],
        orElse: () =>
            throw const FormatException('Region not found in included data'),
      );
      region = Region.fromJson(regionJson, included);
    }

    return Incarnation(
      id: json['id'],
      concept: attributes['concept'],
      mask: attributes['mask'] ?? '',
      region: region,
      placed: attributes['placed'] ?? false,
    );
  }
}
