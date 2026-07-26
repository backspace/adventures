import 'dart:convert';

/// A self-contained, read-only snapshot of the browsable content — the thing
/// that moves device-to-device as an encrypted bundle (see [ViewerBundle]).
///
/// Deliberately independent of the live-game API models: it carries only what a
/// *viewer* renders, and it round-trips through JSON in both directions (the
/// API models are deserialize-only). Keeping it separate also means the app can
/// ship with this and NO content — the dataset only ever arrives at runtime,
/// hand-to-hand, so the sensitive text never sits in the app binary or a server.
class ViewerDataset {
  /// Bumped when the on-the-wire JSON shape changes, so an importer can refuse
  /// (or later migrate) an incompatible bundle instead of mis-parsing it.
  static const int formatVersion = 1;

  final List<ViewerPole> poles;
  final List<ViewerRegion> regions;
  final List<ViewerPuzzlet> puzzlets;

  const ViewerDataset({
    this.poles = const [],
    this.regions = const [],
    this.puzzlets = const [],
  });

  Map<String, dynamic> toJson() => {
        'v': formatVersion,
        'poles': poles.map((p) => p.toJson()).toList(growable: false),
        'regions': regions.map((r) => r.toJson()).toList(growable: false),
        'puzzlets': puzzlets.map((p) => p.toJson()).toList(growable: false),
      };

  factory ViewerDataset.fromJson(Map<String, dynamic> json) {
    final v = json['v'];
    if (v is! int || v > formatVersion) {
      throw FormatException('Unsupported viewer dataset version: $v');
    }
    return ViewerDataset(
      poles: _list(json['poles'], ViewerPole.fromJson),
      regions: _list(json['regions'], ViewerRegion.fromJson),
      puzzlets: _list(json['puzzlets'], ViewerPuzzlet.fromJson),
    );
  }

  /// UTF-8 JSON bytes — the plaintext the bundle codec compresses & encrypts.
  List<int> toJsonBytes() => utf8.encode(jsonEncode(toJson()));

  factory ViewerDataset.fromJsonBytes(List<int> bytes) => ViewerDataset.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);

  int get itemCount => poles.length + regions.length + puzzlets.length;
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) from) =>
    (raw as List?)
        ?.map((e) => from(e as Map<String, dynamic>))
        .toList(growable: false) ??
    const [];

class ViewerPole {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;

  const ViewerPole({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.accessibilityTags = const [],
    this.accessibilityNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': latitude,
        'lng': longitude,
        if (accessibilityTags.isNotEmpty) 'a11y_tags': accessibilityTags,
        if (accessibilityNotes != null) 'a11y_notes': accessibilityNotes,
      };

  factory ViewerPole.fromJson(Map<String, dynamic> j) => ViewerPole(
        id: j['id'] as String,
        name: j['name'] as String,
        latitude: (j['lat'] as num).toDouble(),
        longitude: (j['lng'] as num).toDouble(),
        accessibilityTags: (j['a11y_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: j['a11y_notes'] as String?,
      );
}

class ViewerRegion {
  final String id;
  final String name;
  final String? parentRegionId;
  final String? entryInstructions;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;

  const ViewerRegion({
    required this.id,
    required this.name,
    this.parentRegionId,
    this.entryInstructions,
    this.accessibilityTags = const [],
    this.accessibilityNotes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (parentRegionId != null) 'parent_id': parentRegionId,
        if (entryInstructions != null) 'entry': entryInstructions,
        if (accessibilityTags.isNotEmpty) 'a11y_tags': accessibilityTags,
        if (accessibilityNotes != null) 'a11y_notes': accessibilityNotes,
      };

  factory ViewerRegion.fromJson(Map<String, dynamic> j) => ViewerRegion(
        id: j['id'] as String,
        name: j['name'] as String,
        parentRegionId: j['parent_id'] as String?,
        entryInstructions: j['entry'] as String?,
        accessibilityTags: (j['a11y_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: j['a11y_notes'] as String?,
      );
}

class ViewerPuzzlet {
  final String id;
  final String? poleId;
  final String? regionId;
  final String instructions;
  final String answer;

  /// loose_text | strict_text | barcode | nfc — matches the server enum.
  final String answerType;
  final int difficulty;

  const ViewerPuzzlet({
    required this.id,
    this.poleId,
    this.regionId,
    required this.instructions,
    required this.answer,
    required this.answerType,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        if (poleId != null) 'pole_id': poleId,
        if (regionId != null) 'region_id': regionId,
        'instructions': instructions,
        'answer': answer,
        'answer_type': answerType,
        'difficulty': difficulty,
      };

  factory ViewerPuzzlet.fromJson(Map<String, dynamic> j) => ViewerPuzzlet(
        id: j['id'] as String,
        poleId: j['pole_id'] as String?,
        regionId: j['region_id'] as String?,
        instructions: j['instructions'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        answerType: j['answer_type'] as String? ?? 'loose_text',
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 0,
      );
}
