enum ValidationStatus { assigned, inProgress, submitted, accepted, rejected }

ValidationStatus _vsFromString(String? raw) => switch (raw) {
      'in_progress' => ValidationStatus.inProgress,
      'submitted' => ValidationStatus.submitted,
      'accepted' => ValidationStatus.accepted,
      'rejected' => ValidationStatus.rejected,
      _ => ValidationStatus.assigned,
    };

String validationStatusLabel(ValidationStatus s) => switch (s) {
      ValidationStatus.assigned => 'assigned',
      ValidationStatus.inProgress => 'in progress',
      ValidationStatus.submitted => 'submitted',
      ValidationStatus.accepted => 'accepted',
      ValidationStatus.rejected => 'rejected',
    };

enum CommentStatus { pending, accepted, rejected }

CommentStatus _csFromString(String? raw) => switch (raw) {
      'accepted' => CommentStatus.accepted,
      'rejected' => CommentStatus.rejected,
      _ => CommentStatus.pending,
    };

class ValidationComment {
  final String id;
  final String field;
  final String? comment;
  final String? suggestedValue;
  final CommentStatus status;

  ValidationComment({
    required this.id,
    required this.field,
    required this.comment,
    required this.suggestedValue,
    required this.status,
  });

  factory ValidationComment.fromJson(Map<String, dynamic> json) => ValidationComment(
        id: json['id'] as String,
        field: json['field'] as String,
        comment: json['comment'] as String?,
        suggestedValue: json['suggested_value'] as String?,
        status: _csFromString(json['status'] as String?),
      );
}

class ValidationPoleSummary {
  final String id;
  final String barcode;
  final String? label;
  final double latitude;
  final double longitude;
  final String? notes;
  final String status;

  ValidationPoleSummary({
    required this.id,
    required this.barcode,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.notes,
    required this.status,
  });

  factory ValidationPoleSummary.fromJson(Map<String, dynamic> json) =>
      ValidationPoleSummary(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        label: json['label'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'draft',
      );
}

class ValidationPuzzletSummary {
  final String id;
  final String instructions;
  final String answer;
  final int difficulty;
  final String status;
  final double? latitude;
  final double? longitude;

  ValidationPuzzletSummary({
    required this.id,
    required this.instructions,
    required this.answer,
    required this.difficulty,
    required this.status,
    required this.latitude,
    required this.longitude,
  });

  factory ValidationPuzzletSummary.fromJson(Map<String, dynamic> json) =>
      ValidationPuzzletSummary(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        answer: json['answer'] as String,
        difficulty: json['difficulty'] as int,
        status: json['status'] as String? ?? 'draft',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

class PoleValidationModel {
  final String id;
  final ValidationStatus status;
  final String? overallNotes;
  final String poleId;
  final String validatorId;
  final String? assignedById;
  final ValidationPoleSummary? pole;
  final List<ValidationComment> comments;

  PoleValidationModel({
    required this.id,
    required this.status,
    required this.overallNotes,
    required this.poleId,
    required this.validatorId,
    required this.assignedById,
    required this.pole,
    required this.comments,
  });

  factory PoleValidationModel.fromJson(Map<String, dynamic> json) =>
      PoleValidationModel(
        id: json['id'] as String,
        status: _vsFromString(json['status'] as String?),
        overallNotes: json['overall_notes'] as String?,
        poleId: json['pole_id'] as String,
        validatorId: json['validator_id'] as String,
        assignedById: json['assigned_by_id'] as String?,
        pole: json['pole'] == null
            ? null
            : ValidationPoleSummary.fromJson(json['pole'] as Map<String, dynamic>),
        comments: ((json['comments'] as List?) ?? const [])
            .map((e) => ValidationComment.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class PuzzletValidationModel {
  final String id;
  final ValidationStatus status;
  final String? overallNotes;
  final String puzzletId;
  final String validatorId;
  final String? assignedById;
  final ValidationPuzzletSummary? puzzlet;
  final List<ValidationComment> comments;

  PuzzletValidationModel({
    required this.id,
    required this.status,
    required this.overallNotes,
    required this.puzzletId,
    required this.validatorId,
    required this.assignedById,
    required this.puzzlet,
    required this.comments,
  });

  factory PuzzletValidationModel.fromJson(Map<String, dynamic> json) =>
      PuzzletValidationModel(
        id: json['id'] as String,
        status: _vsFromString(json['status'] as String?),
        overallNotes: json['overall_notes'] as String?,
        puzzletId: json['puzzlet_id'] as String,
        validatorId: json['validator_id'] as String,
        assignedById: json['assigned_by_id'] as String?,
        puzzlet: json['puzzlet'] == null
            ? null
            : ValidationPuzzletSummary.fromJson(
                json['puzzlet'] as Map<String, dynamic>),
        comments: ((json['comments'] as List?) ?? const [])
            .map((e) => ValidationComment.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class MyValidations {
  final List<PoleValidationModel> poleValidations;
  final List<PuzzletValidationModel> puzzletValidations;

  MyValidations({required this.poleValidations, required this.puzzletValidations});

  factory MyValidations.fromJson(Map<String, dynamic> json) => MyValidations(
        poleValidations: (json['pole_validations'] as List)
            .map((e) => PoleValidationModel.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        puzzletValidations: (json['puzzlet_validations'] as List)
            .map((e) =>
                PuzzletValidationModel.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ValidatorUser {
  final String id;
  final String email;
  final String? name;

  ValidatorUser({required this.id, required this.email, required this.name});

  factory ValidatorUser.fromJson(Map<String, dynamic> json) => ValidatorUser(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
      );
}

class DashboardCounts {
  final Map<String, int> poles;
  final Map<String, int> puzzlets;
  final Map<String, int> poleValidations;
  final Map<String, int> puzzletValidations;

  DashboardCounts({
    required this.poles,
    required this.puzzlets,
    required this.poleValidations,
    required this.puzzletValidations,
  });

  int get poleValidationsSubmitted => poleValidations['submitted'] ?? 0;
  int get puzzletValidationsSubmitted => puzzletValidations['submitted'] ?? 0;

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    Map<String, int> readMap(String key) {
      final out = <String, int>{};
      (json[key] as Map?)?.forEach((k, v) => out[k as String] = v as int);
      return out;
    }

    return DashboardCounts(
      poles: readMap('poles'),
      puzzlets: readMap('puzzlets'),
      poleValidations: readMap('pole_validations'),
      puzzletValidations: readMap('puzzlet_validations'),
    );
  }
}
