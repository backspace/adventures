enum DraftStatus { draft, validated, retired }

DraftStatus _statusFromString(String? raw) => switch (raw) {
      'validated' => DraftStatus.validated,
      'retired' => DraftStatus.retired,
      _ => DraftStatus.draft,
    };

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
  final DateTime? insertedAt;

  DraftPuzzlet({
    required this.id,
    required this.instructions,
    required this.answer,
    required this.difficulty,
    required this.status,
    required this.poleId,
    required this.creatorId,
    required this.insertedAt,
  });

  factory DraftPuzzlet.fromJson(Map<String, dynamic> json) => DraftPuzzlet(
        id: json['id'] as String,
        instructions: json['instructions'] as String,
        answer: json['answer'] as String,
        difficulty: json['difficulty'] as int,
        status: _statusFromString(json['status'] as String?),
        poleId: json['pole_id'] as String?,
        creatorId: json['creator_id'] as String?,
        insertedAt: DateTime.tryParse(json['inserted_at'] as String? ?? ''),
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
