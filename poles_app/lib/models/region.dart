class Region {
  final String id;
  final String name;
  final String? parentRegionId;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;
  final String? entryInstructions;

  /// Populated by GET /regions/:id (and after create/update). Ordered
  /// root-most-first, excludes the region itself.
  final List<RegionAncestor> ancestors;

  Region({
    required this.id,
    required this.name,
    required this.parentRegionId,
    this.accessibilityTags = const [],
    this.accessibilityNotes,
    this.entryInstructions,
    this.ancestors = const [],
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as String,
        name: json['name'] as String,
        parentRegionId: json['parent_region_id'] as String?,
        accessibilityTags: (json['accessibility_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: json['accessibility_notes'] as String?,
        entryInstructions: json['entry_instructions'] as String?,
        ancestors: (json['ancestors'] as List?)
                ?.map((e) => RegionAncestor.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const [],
      );

  /// Breadcrumb-style label: "Root > Mid > Self" when ancestors are known,
  /// otherwise just the name. Suitable for display in pickers.
  String get breadcrumb {
    if (ancestors.isEmpty) return name;
    final parts = [...ancestors.map((a) => a.name), name];
    return parts.join(' > ');
  }
}

class RegionAncestor {
  final String id;
  final String name;

  RegionAncestor({required this.id, required this.name});

  factory RegionAncestor.fromJson(Map<String, dynamic> json) =>
      RegionAncestor(id: json['id'] as String, name: json['name'] as String);
}

/// Compact summary of a puzzlet's assigned region, embedded in puzzlet
/// JSON payloads so listings can show "[in Server room]" without a
/// separate roundtrip.
class RegionSummary {
  final String id;
  final String name;
  final String breadcrumb;

  RegionSummary({required this.id, required this.name, required this.breadcrumb});

  factory RegionSummary.fromJson(Map<String, dynamic> json) => RegionSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        breadcrumb: json['breadcrumb'] as String? ?? json['name'] as String,
      );
}

/// One row in the puzzlet's inherited accessibility view. `source` is the
/// ancestor region's name; either `notes` or `entryInstructions` is non-null.
class InheritedStanza {
  final String source;
  final String? notes;
  final String? entryInstructions;

  InheritedStanza({required this.source, this.notes, this.entryInstructions});

  factory InheritedStanza.fromJson(Map<String, dynamic> json) =>
      InheritedStanza(
        source: json['source'] as String,
        notes: json['notes'] as String?,
        entryInstructions: json['entry_instructions'] as String?,
      );
}
