import 'package:waydowntown/models/region.dart';

class Incarnation {
  final String id;
  final String concept;
  final String mask;
  final Region region;

  const Incarnation(
      {required this.id,
      required this.concept,
      required this.mask,
      required this.region});

  factory Incarnation.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    if (relationships == null ||
        relationships['region'] == null ||
        relationships['region']['data'] == null) {
      throw const FormatException('Incarnation must have a region');
    }

    final regionData = relationships['region']['data'];
    final regionJson = included.firstWhere(
      (item) => item['type'] == 'regions' && item['id'] == regionData['id'],
      orElse: () =>
          throw const FormatException('Region not found in included data'),
    );

    return Incarnation(
      id: json['id'],
      concept: attributes['concept'],
      mask: attributes['mask'] ?? '',
      region: Region.fromJson(regionJson, included),
    );
  }
}
