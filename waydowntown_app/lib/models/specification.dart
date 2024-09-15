import 'package:waydowntown/models/region.dart';

class Specification {
  final String id;
  final String concept;
  final int? duration;
  final Region? region;
  final bool placed;
  final String? start;
  final List<String>? answerLabels;

  const Specification({
    required this.id,
    required this.concept,
    this.region,
    this.duration,
    required this.placed,
    this.start,
    this.answerLabels,
  });

  factory Specification.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    Region? region;
    if (attributes['placed'] == true) {
      if (relationships == null ||
          relationships['region'] == null ||
          relationships['region']['data'] == null) {
        throw const FormatException('Placed specification must have a region');
      }

      final regionData = relationships['region']['data'];
      final regionJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == regionData['id'],
        orElse: () =>
            throw const FormatException('Region not found in included data'),
      );
      region = Region.fromJson(regionJson, included);
    }

    return Specification(
      id: json['id'],
      concept: attributes['concept'],
      region: region,
      placed: attributes['placed'] ?? false,
      duration: attributes['duration'],
      start: attributes['start'],
      answerLabels: attributes['answer_labels'] != null
          ? List<String>.from(attributes['answer_labels'])
          : null,
    );
  }
}
