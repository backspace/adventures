import 'package:landgrab/models/region.dart';

enum ValidationStatus {
  assigned,
  inProgress,
  submitted,
  accepted,
  rejected,
  unfindable
}

ValidationStatus _vsFromString(String? raw) => switch (raw) {
      'in_progress' => ValidationStatus.inProgress,
      'submitted' => ValidationStatus.submitted,
      'accepted' => ValidationStatus.accepted,
      'rejected' => ValidationStatus.rejected,
      'unfindable' => ValidationStatus.unfindable,
      _ => ValidationStatus.assigned,
    };

String validationStatusLabel(ValidationStatus s) => switch (s) {
      ValidationStatus.assigned => 'assigned',
      ValidationStatus.inProgress => 'in progress',
      ValidationStatus.submitted => 'submitted',
      ValidationStatus.accepted => 'accepted',
      ValidationStatus.rejected => 'rejected',
      ValidationStatus.unfindable => 'unfindable',
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

List<String> _attachmentIdsFromJson(dynamic raw) =>
    (raw as List?)?.map((e) => e as String).toList(growable: false) ?? const [];

/// Outcome of resolving a scanned barcode against a validator's
/// assignments, relative to the pole they tapped.
enum ScanMatch {
  /// Scanned the pole they tapped — physically confirmed.
  matched,

  /// Scanned a different pole that's also assigned to them.
  other,

  /// Scanned something not assigned to them (or no such pole).
  unknown,
}

class ScanResolution {
  final ScanMatch outcome;

  /// The validation to open (the tapped one for [ScanMatch.matched], the
  /// other one for [ScanMatch.other], null for [ScanMatch.unknown]).
  final String? validationId;
  final String scannedBarcode;

  ScanResolution({
    required this.outcome,
    this.validationId,
    required this.scannedBarcode,
  });

  factory ScanResolution.fromJson(Map<String, dynamic> json) => ScanResolution(
        outcome: switch (json['outcome']) {
          'matched' => ScanMatch.matched,
          'other' => ScanMatch.other,
          _ => ScanMatch.unknown,
        },
        validationId: json['validation_id'] as String?,
        scannedBarcode: json['scanned_barcode'] as String? ?? '',
      );
}

class ValidationPoleSummary {
  final String id;
  final String barcode;
  final String? label;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? manualOffsetM;
  final String? notes;
  final String status;
  final List<String> attachmentIds;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;

  ValidationPoleSummary({
    required this.id,
    required this.barcode,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.manualOffsetM,
    required this.notes,
    required this.status,
    this.attachmentIds = const [],
    this.accessibilityTags = const [],
    this.accessibilityNotes,
  });

  factory ValidationPoleSummary.fromJson(Map<String, dynamic> json) =>
      ValidationPoleSummary(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        label: json['label'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        manualOffsetM: (json['manual_offset_m'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        status: json['status'] as String? ?? 'draft',
        attachmentIds: _attachmentIdsFromJson(json['attachment_ids']),
        accessibilityTags: (json['accessibility_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: json['accessibility_notes'] as String?,
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
  final List<String> attachmentIds;
  final RegionSummary? region;

  ValidationPuzzletSummary({
    required this.id,
    required this.instructions,
    required this.answer,
    required this.difficulty,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.attachmentIds = const [],
    this.region,
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
        attachmentIds: _attachmentIdsFromJson(json['attachment_ids']),
        region: json['region'] == null
            ? null
            : RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
      );
}

class PoleValidationModel {
  final String id;
  final ValidationStatus status;
  final String? overallNotes;
  final bool physicallyVerified;
  final String poleId;
  final String validatorId;
  final ValidatorUser? validator;
  final String? assignedById;
  final ValidationPoleSummary? pole;
  final List<ValidationComment> comments;

  PoleValidationModel({
    required this.id,
    required this.status,
    required this.overallNotes,
    this.physicallyVerified = false,
    required this.poleId,
    required this.validatorId,
    this.validator,
    required this.assignedById,
    required this.pole,
    required this.comments,
  });

  factory PoleValidationModel.fromJson(Map<String, dynamic> json) =>
      PoleValidationModel(
        id: json['id'] as String,
        status: _vsFromString(json['status'] as String?),
        overallNotes: json['overall_notes'] as String?,
        physicallyVerified: json['physically_verified'] as bool? ?? false,
        poleId: json['pole_id'] as String,
        validatorId: json['validator_id'] as String,
        validator: json['validator'] == null
            ? null
            : ValidatorUser.fromJson(json['validator'] as Map<String, dynamic>),
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
  final ValidatorUser? validator;
  final String? assignedById;
  final ValidationPuzzletSummary? puzzlet;
  final List<ValidationComment> comments;

  PuzzletValidationModel({
    required this.id,
    required this.status,
    required this.overallNotes,
    required this.puzzletId,
    required this.validatorId,
    this.validator,
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
        validator: json['validator'] == null
            ? null
            : ValidatorUser.fromJson(json['validator'] as Map<String, dynamic>),
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
