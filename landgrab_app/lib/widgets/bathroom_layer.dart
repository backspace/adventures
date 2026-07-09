import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/models/accessibility.dart';
import 'package:landgrab/models/bathroom.dart';

/// A MarkerLayer for the bathrooms recorded in the current event.
/// Bathrooms whose recorded coordinates are within `_groupThresholdM`
/// of each other are treated as being in the same building and
/// rendered as a single marker with a count badge — tapping shows a
/// list; tapping a single-bathroom marker shows the details directly.
///
/// GPS accuracy on phones is typically 5–10 m, so 15 m catches the
/// same-building case (multiple bathrooms recorded at essentially
/// the same street entrance) without merging neighbouring buildings.
class BathroomLayer extends StatelessWidget {
  final List<Bathroom> bathrooms;

  const BathroomLayer({super.key, required this.bathrooms});

  static const double _groupThresholdM = 15.0;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByProximity(bathrooms);
    return MarkerLayer(
      markers: groups
          .map((group) => Marker(
                point: LatLng(group.first.latitude, group.first.longitude),
                width: 32,
                height: 32,
                child: _BathroomMarker(
                  group: group,
                  onTap: () => _showSheet(context, group),
                ),
              ))
          .toList(growable: false),
    );
  }

  static List<List<Bathroom>> _groupByProximity(List<Bathroom> input) {
    const distance = Distance();
    final groups = <List<Bathroom>>[];
    for (final b in input) {
      final point = LatLng(b.latitude, b.longitude);
      List<Bathroom>? match;
      for (final group in groups) {
        final anchor = group.first;
        final d = distance.as(
          LengthUnit.Meter,
          LatLng(anchor.latitude, anchor.longitude),
          point,
        );
        if (d <= _groupThresholdM) {
          match = group;
          break;
        }
      }
      if (match != null) {
        match.add(b);
      } else {
        groups.add([b]);
      }
    }
    return groups;
  }

  static void _showSheet(BuildContext context, List<Bathroom> group) {
    showModalBottomSheet(
      context: context,
      // `isScrollControlled: true` lets the sheet grow beyond half-
      // screen when content is long. Combined with intrinsic sizing
      // below, a short-noted bathroom sheet stays compact and a
      // long-noted / many-bathrooms sheet grows up to the max cap.
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: group.length == 1
                  ? _BathroomDetails(bathroom: group.single)
                  : _GroupContent(group: group),
            ),
          ),
        );
      },
    );
  }
}

class _GroupContent extends StatelessWidget {
  final List<Bathroom> group;
  const _GroupContent({required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${group.length} bathrooms here',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final bathroom in group)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                title: Text(bathroom.displayName()),
                subtitle: bathroom.region == null
                    ? null
                    : Text(bathroom.region!.breadcrumb),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _BathroomDetails(
                      bathroom: bathroom,
                      hideName: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BathroomMarker extends StatelessWidget {
  final List<Bathroom> group;
  final VoidCallback onTap;

  const _BathroomMarker({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: group.length == 1
            ? group.single.displayName()
            : '${group.length} bathrooms',
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(Icons.wash, color: Colors.blueGrey.shade700, size: 24),
            if (group.length > 1)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '${group.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The details content for a single bathroom. Rendered directly in
/// the sheet for single-bathroom taps, and inside each ExpansionTile
/// row for group taps (with `hideName: true` since the tile itself
/// already shows the name).
class _BathroomDetails extends StatelessWidget {
  final Bathroom bathroom;
  final bool hideName;

  const _BathroomDetails({required this.bathroom, this.hideName = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTags = <String>{
      ...bathroom.accessibilityTags,
      ...bathroom.inheritedTags,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideName)
          Text(bathroom.displayName(), style: theme.textTheme.titleLarge),
        if (!hideName && bathroom.region != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              bathroom.region!.breadcrumb,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: allTags
                .map((t) => Chip(
                      label: Text(accessibilityTagLabel(t)),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(growable: false),
          ),
        ],
        _Section(label: 'Access', body: bathroom.accessibilityNotes),
        _Section(label: 'Entry', body: bathroom.entryInstructions),
        _Section(label: 'Notes', body: bathroom.notes),
        // Inherited notes/instructions from parent regions — surfaced
        // so a bathroom inside a building with locked-after-hours
        // entry, for example, carries that constraint into the sheet
        // automatically without duplicating text on every bathroom.
        for (final stanza in bathroom.inheritedStanzas) ...[
          if (stanza.notes != null && stanza.notes!.trim().isNotEmpty)
            _Section(label: 'From ${stanza.source}', body: stanza.notes),
          if (stanza.entryInstructions != null &&
              stanza.entryInstructions!.trim().isNotEmpty)
            _Section(
              label: 'Entry via ${stanza.source}',
              body: stanza.entryInstructions,
            ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String? body;

  const _Section({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    final trimmed = body?.trim();
    if (trimmed == null || trimmed.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(trimmed, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
