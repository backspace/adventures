import 'package:waydowntown/models/region.dart';

class Answer {
  final String id;
  final String? label;
  final int? order;
  final Region? region;

  final String? hint;
  final bool hasHint;

  const Answer({
    required this.id,
    required this.label,
    this.order,
    this.region,
    this.hint,
    this.hasHint = false,
  });

  factory Answer.fromJson(Map<String, dynamic> json,
      [List<dynamic>? included]) {
    final attributes = json['attributes'] as Map<String, dynamic>?;
    Region? region;
    final relationships = json['relationships'];
    if (included != null &&
        relationships != null &&
        relationships['region'] != null &&
        relationships['region']['data'] != null) {
      final regionData = relationships['region']['data'];
      final regionJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == regionData['id'],
        orElse: () => <String, Object>{},
      );

      if (regionJson.isNotEmpty) {
        region = Region.fromJson(regionJson, included);
      }
    }

    return Answer(
      id: json['id'],
      label: attributes?['label'],
      order: attributes?['order'],
      region: region,
      hint: attributes?['hint'],
      hasHint: attributes?['has_hint'] == true,
    );
  }
}
