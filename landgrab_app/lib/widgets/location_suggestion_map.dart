import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/widgets/mini_location_map.dart';

/// For a `location` suggested-change comment, draws the proposed coordinates
/// on a mini map so a supervisor can eyeball the move instead of parsing the
/// raw JSON bundle. Shown alongside (not instead of) the serialized value.
///
/// Renders nothing for any other field, or if the bundle can't be parsed —
/// so it's safe to drop into any comment's layout unconditionally.
class LocationSuggestionMap extends StatelessWidget {
  final ValidationComment comment;

  const LocationSuggestionMap({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    if (comment.field != 'location' || comment.suggestedValue == null) {
      return const SizedBox.shrink();
    }
    double? lat;
    double? lng;
    double? accuracyM;
    try {
      final m = jsonDecode(comment.suggestedValue!) as Map<String, dynamic>;
      lat = (m['latitude'] as num?)?.toDouble();
      lng = (m['longitude'] as num?)?.toDouble();
      accuracyM = (m['accuracy_m'] as num?)?.toDouble();
    } catch (_) {
      return const SizedBox.shrink();
    }
    if (lat == null || lng == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MiniLocationMap.pole(
        latitude: lat,
        longitude: lng,
        label: 'Suggested location',
        color: Theme.of(context).colorScheme.primary,
        accuracyM: accuracyM,
        height: 150,
      ),
    );
  }
}
