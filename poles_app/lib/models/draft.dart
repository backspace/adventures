enum DraftStatus { draft, inReview, validated, retired }

DraftStatus _statusFromString(String? raw) => switch (raw) {
      'in_review' => DraftStatus.inReview,
      'validated' => DraftStatus.validated,
      'retired' => DraftStatus.retired,
      _ => DraftStatus.draft,
    };

String draftStatusLabel(DraftStatus s) => switch (s) {
      DraftStatus.draft => 'draft',
      DraftStatus.inReview => 'in_review',
      DraftStatus.validated => 'validated',
      DraftStatus.retired => 'retired',
    };

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
      );
}

class DraftPuzzlet {
  final String id;
  final String instructions;
  final String answer;
  final int difficulty;
  final DraftStatus status;
  final String? poleId;
  final String? creatorId;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? insertedAt;
  final ActiveValidationSummary? activeValidation;

  DraftPuzzlet({
    required this.id,
    required this.instructions,
    required this.answer,
    required this.difficulty,
    required this.status,
    required this.poleId,
    required this.creatorId,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.insertedAt,
    this.activeValidation,
  });

  factory DraftPuzzlet.fromJson(Map<String, dynamic> json) => DraftPuzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        answer: json['answer'] as String,
        difficulty: json['difficulty'] as int,
        status: _statusFromString(json['status'] as String?),
        poleId: json['pole_id'] as String?,
        creatorId: json['creator_id'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        insertedAt: DateTime.tryParse(json['inserted_at'] as String? ?? ''),
        activeValidation: json['active_validation'] == null
            ? null
            : ActiveValidationSummary.fromJson(
                json['active_validation'] as Map<String, dynamic>),
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
