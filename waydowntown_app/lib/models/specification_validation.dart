import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/models/validation_comment.dart';

class SpecificationValidation {
  final String id;
  final String status;
  final String? playMode;
  final String? overallNotes;
  final Specification? specification;
  final String? validatorId;
  final String? validatorName;
  final String? assignedById;
  final String? assignedByName;
  final String? runId;
  final List<ValidationComment> comments;

  const SpecificationValidation({
    required this.id,
    required this.status,
    this.playMode,
    this.overallNotes,
    this.specification,
    this.validatorId,
    this.validatorName,
    this.assignedById,
    this.assignedByName,
    this.runId,
    this.comments = const [],
  });

  factory SpecificationValidation.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'] as Map<String, dynamic>?;
    final relationships = json['relationships'] as Map<String, dynamic>?;

    Specification? specification;
    if (relationships != null &&
        relationships['specification'] != null &&
        relationships['specification']['data'] != null) {
      final specData = relationships['specification']['data'];
      final specJson = included.firstWhere(
        (item) =>
            item['type'] == 'specifications' && item['id'] == specData['id'],
        orElse: () => null,
      );
      if (specJson != null) {
        specification = Specification.fromJson(specJson, included);
      }
    }

    String? validatorId;
    String? validatorName;
    if (relationships != null &&
        relationships['validator'] != null &&
        relationships['validator']['data'] != null) {
      validatorId = relationships['validator']['data']['id'];
      final validatorJson = included.firstWhere(
        (item) =>
            item['type'] == 'users' && item['id'] == validatorId,
        orElse: () => null,
      );
      if (validatorJson != null) {
        validatorName = validatorJson['attributes']?['name'] ??
            validatorJson['attributes']?['email'];
      }
    }

    String? assignedById;
    String? assignedByName;
    if (relationships != null &&
        relationships['assigned-by'] != null &&
        relationships['assigned-by']['data'] != null) {
      assignedById = relationships['assigned-by']['data']['id'];
      final assignerJson = included.firstWhere(
        (item) =>
            item['type'] == 'users' && item['id'] == assignedById,
        orElse: () => null,
      );
      if (assignerJson != null) {
        assignedByName = assignerJson['attributes']?['name'] ??
            assignerJson['attributes']?['email'];
      }
    }

    String? runId;
    if (relationships != null &&
        relationships['run'] != null &&
        relationships['run']['data'] != null) {
      runId = relationships['run']['data']['id'];
    }

    List<ValidationComment> comments = [];
    if (relationships != null &&
        relationships['validation-comments'] != null &&
        relationships['validation-comments']['data'] != null) {
      final commentDataList =
          relationships['validation-comments']['data'] as List<dynamic>;
      for (final commentData in commentDataList) {
        final commentJson = included.firstWhere(
          (item) =>
              item['type'] == 'validation-comments' &&
              item['id'] == commentData['id'],
          orElse: () => null,
        );
        if (commentJson != null) {
          comments.add(ValidationComment.fromJson(commentJson, included));
        }
      }
    }

    return SpecificationValidation(
      id: json['id'],
      status: attributes?['status'] ?? 'assigned',
      playMode: attributes?['play_mode'],
      overallNotes: attributes?['overall_notes'],
      specification: specification,
      validatorId: validatorId,
      validatorName: validatorName,
      assignedById: assignedById,
      assignedByName: assignedByName,
      runId: runId,
      comments: comments,
    );
  }
}
