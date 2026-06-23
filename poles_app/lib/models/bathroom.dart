import 'package:poles/models/region.dart';

class Bathroom {
  final String id;
  final String? name;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final String? notes;
  final List<String> accessibilityTags;
  final String? accessibilityNotes;
  final String? entryInstructions;
  final String? regionId;
  final RegionSummary? region;
  final String? creatorId;
  final DateTime? insertedAt;
  final DateTime? updatedAt;
  final List<String> inheritedTags;
  final List<InheritedStanza> inheritedStanzas;

  Bathroom({
    required this.id,
    this.name,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.notes,
    this.accessibilityTags = const [],
    this.accessibilityNotes,
    this.entryInstructions,
    this.regionId,
    this.region,
    this.creatorId,
    this.insertedAt,
    this.updatedAt,
    this.inheritedTags = const [],
    this.inheritedStanzas = const [],
  });

  /// Fallback label when name is null/empty — fall back to coords so the
  /// pin tooltip / list row still has something readable.
  String displayName() {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'Bathroom';
  }

  factory Bathroom.fromJson(Map<String, dynamic> json) => Bathroom(
        id: json['id'] as String,
        name: json['name'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        accessibilityTags: (json['accessibility_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        accessibilityNotes: json['accessibility_notes'] as String?,
        entryInstructions: json['entry_instructions'] as String?,
        regionId: json['region_id'] as String?,
        region: json['region'] == null
            ? null
            : RegionSummary.fromJson(json['region'] as Map<String, dynamic>),
        creatorId: json['creator_id'] as String?,
        insertedAt: DateTime.tryParse(json['inserted_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        inheritedTags: (json['inherited_tags'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
        inheritedStanzas: (json['inherited_stanzas'] as List?)
                ?.map((e) => InheritedStanza.fromJson(e as Map<String, dynamic>))
                .toList(growable: false) ??
            const [],
      );
}
