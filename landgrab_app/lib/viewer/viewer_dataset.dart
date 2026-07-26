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

  ViewerRegion? regionById(String? id) {
    if (id == null) return null;
    for (final r in regions) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Puzzlets grouped by their region: named regions first (alphabetical), then
  /// a trailing "no region" bucket. Within each group, puzzlets are ordered by
  /// difficulty then instructions. A [regionId] that doesn't resolve to a known
  /// region falls into the no-region bucket.
  List<RegionGroup> groupedByRegion() {
    final byId = {for (final r in regions) r.id: r};
    final buckets = <String?, List<ViewerPuzzlet>>{};
    for (final p in puzzlets) {
      final key = byId.containsKey(p.regionId) ? p.regionId : null;
      (buckets[key] ??= []).add(p);
    }

    int cmp(ViewerPuzzlet a, ViewerPuzzlet b) {
      final d = a.difficulty.compareTo(b.difficulty);
      return d != 0 ? d : a.instructions.compareTo(b.instructions);
    }

    final namedKeys = buckets.keys.whereType<String>().toList()
      ..sort((a, b) =>
          byId[a]!.name.toLowerCase().compareTo(byId[b]!.name.toLowerCase()));

    final groups = [
      for (final k in namedKeys)
        RegionGroup(region: byId[k], puzzlets: [...buckets[k]!]..sort(cmp)),
    ];
    if (buckets.containsKey(null)) {
      groups.add(
          RegionGroup(region: null, puzzlets: [...buckets[null]!]..sort(cmp)));
    }
    return groups;
  }
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

  /// Puzzlet's own location, when it has one. Regions don't carry coordinates
  /// yet, so the map plots puzzlets; those without a location are list-only.
  final double? latitude;
  final double? longitude;

  const ViewerPuzzlet({
    required this.id,
    this.poleId,
    this.regionId,
    required this.instructions,
    required this.answer,
    required this.answerType,
    required this.difficulty,
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        if (poleId != null) 'pole_id': poleId,
        if (regionId != null) 'region_id': regionId,
        'instructions': instructions,
        'answer': answer,
        'answer_type': answerType,
        'difficulty': difficulty,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
      };

  factory ViewerPuzzlet.fromJson(Map<String, dynamic> j) => ViewerPuzzlet(
        id: j['id'] as String,
        poleId: j['pole_id'] as String?,
        regionId: j['region_id'] as String?,
        instructions: j['instructions'] as String? ?? '',
        answer: j['answer'] as String? ?? '',
        answerType: j['answer_type'] as String? ?? 'loose_text',
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 0,
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lng'] as num?)?.toDouble(),
      );
}

/// A region and the puzzlets in it — the unit the browser groups by. A null
/// [region] is the "no region" bucket.
class RegionGroup {
  final ViewerRegion? region;
  final List<ViewerPuzzlet> puzzlets;
  const RegionGroup({required this.region, required this.puzzlets});

  String get title => region?.name ?? 'No region';
  int get located => puzzlets.where((p) => p.hasLocation).length;
}
