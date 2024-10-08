import 'package:waydowntown/models/specification.dart';

class Run {
  final String id;
  final Specification specification;
  final int correctSubmissions;
  final int totalAnswers;
  final DateTime? startedAt;
  final String? taskDescription;
  final bool isComplete;

  Run({
    required this.id,
    required this.specification,
    required this.correctSubmissions,
    required this.totalAnswers,
    this.startedAt,
    this.taskDescription,
    this.isComplete = false,
  });

  factory Run.fromJson(Map<String, dynamic> json,
      {Specification? existingSpecification}) {
    final data = json['data'];
    final included = json['included'] as List<dynamic>?;

    Specification? specification = existingSpecification;
    if (specification == null &&
        included != null &&
        data['relationships'] != null &&
        data['relationships']['specification'] != null) {
      final specificationData = data['relationships']['specification']['data'];
      final specificationJson = included.firstWhere(
        (item) =>
            item['type'] == 'specifications' &&
            item['id'] == specificationData['id'],
        orElse: () => null,
      );
      if (specificationJson != null) {
        specification = Specification.fromJson(specificationJson, included);
      }
    }

    return Run(
      id: data['id'],
      specification: specification ??
          (throw const FormatException('Run must have a specification')),
      taskDescription: data['attributes']['task_description'],
      correctSubmissions: data['attributes']['correct_submissions'] ?? 0,
      totalAnswers: data['attributes']['total_answers'] ?? 0,
      startedAt: data['attributes']['started_at'] != null
          ? DateTime.parse(data['attributes']['started_at'])
          : null,
      isComplete: data['attributes']['complete'] ?? false,
    );
  }
}
