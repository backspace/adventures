import 'package:landgrab/models/region.dart';

enum DraftStatus { draft, inReview, validated, retired }

enum AnswerType { looseText, strictText, barcode, nfc }

AnswerType answerTypeFromString(String? raw) => switch (raw) {
      'strict_text' => AnswerType.strictText,
      'barcode' => AnswerType.barcode,
      'nfc' => AnswerType.nfc,
      _ => AnswerType.looseText,
    };

String answerTypeToString(AnswerType t) => switch (t) {
      AnswerType.looseText => 'loose_text',
      AnswerType.strictText => 'strict_text',
      AnswerType.barcode => 'barcode',
      AnswerType.nfc => 'nfc',
    };

String answerTypeLabel(AnswerType t) => switch (t) {
      AnswerType.looseText => 'Loose text',
      AnswerType.strictText => 'Strict text',
      AnswerType.barcode => 'Barcode',
      AnswerType.nfc => 'NFC tag',
    };

DraftStatus _statusFromString(String? raw) => switch (raw) {
      'in_review' => DraftStatus.inReview,
      'validated' => DraftStatus.validated,
      'retired' => DraftStatus.retired,
      _ => DraftStatus.draft,
    };

String draftStatusLabel(DraftStatus s) => switch (s) {
      DraftStatus.draft => 'draft',
      DraftStatus.inReview => 'in review',
      DraftStatus.validated => 'validated',
      DraftStatus.retired => 'retired',
    };

/// Human-readable form of a raw status string from the API (e.g. the keys
/// in `DashboardCounts.poles`). Just swaps underscores for spaces so a
/// payload like `"in_review"` renders as `"in review"`.
String prettifyStatus(String raw) => raw.replaceAll('_', ' ');

class ActiveValidationSummary {
  final String id;
  final String status;
  final int commentCount;

  ActiveValidationSummary({
    required this.id,
    required this.status,
    required this.commentCount,
  });

  factory ActiveValidationSummary.fromJson(Map<String, dynamic> json) =>
      ActiveValidationSummary(
        id: json['id'] as String,
        status: json['status'] as String,
        commentCount: json['comment_count'] as int? ?? 0,
      );
}

class DraftPole {
  final String id;
  final String barcode;
  final String? label;
  final double latitude;
  final double longitude;
  final String? notes;
  final double? accuracyM;
  final DraftStatus status;
  final String? creatorId;
  final DateTime? insertedAt;
  final ActiveValidationSummary? activeValidation;
  final List<String> attachmentIds;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;

  DraftPole({
    required this.id,
    required this.barcode,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.notes,
    required this.accuracyM,
    required this.status,
    required this.creatorId,
    required this.insertedAt,
    this.activeValidation,
    this.attachmentIds = const [],
    this.accessibilityTags = const [],
    this.accessibilityNotes,
  });

  factory DraftPole.fromJson(Map<String, dynamic> json) => DraftPole(
        id: json['id'] as String,
        barcode: json['barcode'] as String,
        label: json['label'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        notes: json['notes'] as String?,
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        status: _statusFromString(json['status'] as String?),
        creatorId: json['creator_id'] as String?,
        insertedAt: DateTime.tryParse(json['inserted_at'] as String? ?? ''),
        activeValidation: json['active_validation'] == null
            ? null
            : ActiveValidationSummary.fromJson(
                json['active_validation'] as Map<String, dynamic>),
        attachmentIds: (json['attachment_ids'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityTags: (json['accessibility_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: json['accessibility_notes'] as String?,
      );

  DraftPole copyWith({List<String>? attachmentIds}) => DraftPole(
        id: id,
        barcode: barcode,
        label: label,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        accuracyM: accuracyM,
        status: status,
        creatorId: creatorId,
        insertedAt: insertedAt,
        activeValidation: activeValidation,
        attachmentIds: attachmentIds ?? this.attachmentIds,
        accessibilityTags: accessibilityTags,
        accessibilityNotes: accessibilityNotes,
      );
}

class DraftPuzzlet {
  final String id;
  final String instructions;
  final String answer;
  final AnswerType answerType;
  final int difficulty;
  final DraftStatus status;
  final String? poleId;
  final String? regionId;
  final RegionSummary? region;
  final String? creatorId;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? insertedAt;
  final ActiveValidationSummary? activeValidation;
  final List<String> attachmentIds;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;
  final List<String> inheritedTags;
  final List<InheritedStanza> inheritedStanzas;
  final String? warning;

  DraftPuzzlet({
    required this.id,
    required this.instructions,
    required this.answer,
    this.answerType = AnswerType.looseText,
    required this.difficulty,
    required this.status,
    required this.poleId,
    this.regionId,
    this.region,
    required this.creatorId,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.insertedAt,
    this.activeValidation,
    this.attachmentIds = const [],
    this.accessibilityTags = const [],
    this.accessibilityNotes,
    this.inheritedTags = const [],
    this.inheritedStanzas = const [],
    this.warning,
  });

  factory DraftPuzzlet.fromJson(Map<String, dynamic> json) => DraftPuzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        answer: json['answer'] as String,
        answerType: answerTypeFromString(json['answer_type'] as String?),
        difficulty: json['difficulty'] as int,
        status: _statusFromString(json['status'] as String?),
        poleId: json['pole_id'] as String?,
        regionId: json['region_id'] as String?,
        region: json['region'] == null
            ? null
            : RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
        creatorId: json['creator_id'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        insertedAt: DateTime.tryParse(json['inserted_at'] as String? ?? ''),
        activeValidation: json['active_validation'] == null
            ? null
            : ActiveValidationSummary.fromJson(
                json['active_validation'] as Map<String, dynamic>),
        attachmentIds: (json['attachment_ids'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityTags: (json['accessibility_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: json['accessibility_notes'] as String?,
        inheritedTags: (json['inherited_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        inheritedStanzas: (json['inherited_stanzas'] as List?)
                ?.map((e) => InheritedStanza.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const [],
        warning: json['warning'] as String?,
      );

  DraftPuzzlet copyWith({List<String>? attachmentIds}) => DraftPuzzlet(
        id: id,
        instructions: instructions,
        answer: answer,
        answerType: answerType,
        difficulty: difficulty,
        status: status,
        poleId: poleId,
        regionId: regionId,
        region: region,
        creatorId: creatorId,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        insertedAt: insertedAt,
        activeValidation: activeValidation,
        attachmentIds: attachmentIds ?? this.attachmentIds,
        accessibilityTags: accessibilityTags,
        accessibilityNotes: accessibilityNotes,
        inheritedTags: inheritedTags,
        inheritedStanzas: inheritedStanzas,
        warning: warning,
      );
}

class MyDrafts {
  final List<DraftPole> poles;
  final List<DraftPuzzlet> puzzlets;

  MyDrafts({required this.poles, required this.puzzlets});

  factory MyDrafts.fromJson(Map<String, dynamic> json) => MyDrafts(
        poles: (json['poles'] as List)
            .map((e) => DraftPole.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        puzzlets: (json['puzzlets'] as List)
            .map((e) => DraftPuzzlet.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
