import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:landgrab/viewer/secure_screen_guard.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';

/// Read-only browser over an imported [ViewerDataset]. No API, no game state —
/// just the content: puzzlets grouped by region (or flat, by difficulty), a
/// region-coloured map, and the region/stake lists.
class ViewerBrowseRoute extends StatelessWidget {
  final ViewerDataset dataset;
  const ViewerBrowseRoute({super.key, required this.dataset});

  @override
  Widget build(BuildContext context) {
    return SecureScreenGuard(
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Browse'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Puzzlets'),
                Tab(text: 'Map'),
                Tab(text: 'Regions'),
                Tab(text: 'Stakes'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _PuzzletTab(dataset: dataset),
              _PuzzletMap(dataset: dataset),
              _RegionList(regions: dataset.regions),
              _PoleList(poles: dataset.poles),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stable, distinct colour per region (null = the "no region" bucket).
Color regionColor(String? regionId) {
  if (regionId == null) return const Color(0xFF78909C); // blue-grey
  final hue = (regionId.hashCode & 0x7fffffff) % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.5).toColor();
}

// ─────────────────────────── Puzzlets (list) ───────────────────────────

class _PuzzletTab extends StatefulWidget {
  final ViewerDataset dataset;
  const _PuzzletTab({required this.dataset});

  @override
  State<_PuzzletTab> createState() => _PuzzletTabState();
}

class _PuzzletTabState extends State<_PuzzletTab> {
  bool _grouped = true;

  @override
  Widget build(BuildContext context) {
    if (widget.dataset.puzzlets.isEmpty) {
      return const _Empty('No puzzlets in this bundle.');
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  label: Text('By region'),
                  icon: Icon(Icons.category_outlined)),
              ButtonSegment(
                  value: false,
                  label: Text('By difficulty'),
                  icon: Icon(Icons.sort)),
            ],
            selected: {_grouped},
            onSelectionChanged: (s) => setState(() => _grouped = s.first),
          ),
        ),
        Expanded(
          child: _grouped
              ? _GroupedPuzzlets(dataset: widget.dataset)
              : _FlatPuzzlets(dataset: widget.dataset),
        ),
      ],
    );
  }
}

class _GroupedPuzzlets extends StatelessWidget {
  final ViewerDataset dataset;
  const _GroupedPuzzlets({required this.dataset});

  @override
  Widget build(BuildContext context) {
    final groups = dataset.groupedByRegion();
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        return ExpansionTile(
          initiallyExpanded: groups.length <= 3,
          leading: _ColorDot(regionColor(g.region?.id)),
          title: Text(g.title),
          subtitle: Text('${g.puzzlets.length} puzzlets'
              '${g.located < g.puzzlets.length ? ' · ${g.located} on map' : ''}'),
          children: [
            for (final p in g.puzzlets)
              _PuzzletTile(puzzlet: p, dataset: dataset, showRegion: false),
          ],
        );
      },
    );
  }
}

class _FlatPuzzlets extends StatelessWidget {
  final ViewerDataset dataset;
  const _FlatPuzzlets({required this.dataset});

  @override
  Widget build(BuildContext context) {
    // Hardest first — the "by difficulty" view leads with the top difficulty.
    final puzzlets = [...dataset.puzzlets]..sort((a, b) {
        final d = b.difficulty.compareTo(a.difficulty);
        return d != 0 ? d : a.instructions.compareTo(b.instructions);
      });
    return ListView.separated(
      itemCount: puzzlets.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) =>
          _PuzzletTile(puzzlet: puzzlets[i], dataset: dataset, showRegion: true),
    );
  }
}

class _PuzzletTile extends StatelessWidget {
  final ViewerPuzzlet puzzlet;
  final ViewerDataset dataset;
  final bool showRegion;
  const _PuzzletTile({
    required this.puzzlet,
    required this.dataset,
    required this.showRegion,
  });

  @override
  Widget build(BuildContext context) {
    final region = dataset.regionById(puzzlet.regionId);
    final sub = <String>[
      puzzlet.answerType,
      if (showRegion) region?.name ?? 'No region',
      if (!puzzlet.hasLocation) 'no location',
    ].join(' · ');
    return ListTile(
      leading: _DifficultyBadge(puzzlet.difficulty),
      title: Text(
        puzzlet.instructions.isEmpty ? '(no instructions)' : puzzlet.instructions,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(sub),
      onTap: () => showPuzzletDetail(context, puzzlet, dataset),
    );
  }
}

/// Full puzzlet detail, shared by the list and the map. Bottom sheet.
void showPuzzletDetail(
    BuildContext context, ViewerPuzzlet p, ViewerDataset dataset) {
  final region = dataset.regionById(p.regionId);
  final pole = () {
    for (final s in dataset.poles) {
      if (s.id == p.poleId) return s;
    }
    return null;
  }();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(label: 'Instructions', value: p.instructions),
              _Field(label: 'Answer', value: p.answer, mono: true),
              _Field(label: 'Answer type', value: p.answerType),
              _Field(label: 'Difficulty', value: '${p.difficulty}'),
              _Field(label: 'Region', value: region?.name ?? 'No region'),
              if (pole != null) _Field(label: 'Stake', value: pole.name),
              _Field(
                label: 'Location',
                value: p.hasLocation
                    ? '${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}'
                    : '—',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────── Puzzlets (map) ───────────────────────────

class _PuzzletMap extends StatelessWidget {
  final ViewerDataset dataset;
  const _PuzzletMap({required this.dataset});

  @override
  Widget build(BuildContext context) {
    final located = dataset.puzzlets.where((p) => p.hasLocation).toList();
    if (located.isEmpty) {
      return const _Empty(
          'No puzzlets have locations to map yet.\nThey\'re still browsable in the list.');
    }
    final points = [
      for (final p in located) LatLng(p.latitude!, p.longitude!),
    ];
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
        // Match the game maps: rotation off (it's disorienting and easy to
        // trigger by accident).
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        landgrabTileLayer(context),
        MarkerLayer(
          markers: [
            for (final p in located)
              Marker(
                point: LatLng(p.latitude!, p.longitude!),
                width: 22,
                height: 22,
                child: GestureDetector(
                  onTap: () => showPuzzletDetail(context, p, dataset),
                  child: _MapDot(color: regionColor(p.regionId)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MapDot extends StatelessWidget {
  final Color color;
  const _MapDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
    );
  }
}

// ─────────────────────────── Regions / Stakes ───────────────────────────

class _RegionList extends StatelessWidget {
  final List<ViewerRegion> regions;
  const _RegionList({required this.regions});

  @override
  Widget build(BuildContext context) {
    if (regions.isEmpty) return const _Empty('No regions in this bundle.');
    final sorted = [...regions]..sort((a, b) => a.name.compareTo(b.name));
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = sorted[i];
        final entry = r.entryInstructions ?? '';
        return ListTile(
          leading: _ColorDot(regionColor(r.id)),
          title: Text(r.name),
          subtitle: entry.isEmpty ? null : Text(entry),
          isThreeLine: entry.isNotEmpty,
        );
      },
    );
  }
}

class _PoleList extends StatelessWidget {
  final List<ViewerPole> poles;
  const _PoleList({required this.poles});

  @override
  Widget build(BuildContext context) {
    if (poles.isEmpty) return const _Empty('No stakes in this bundle.');
    final sorted = [...poles]..sort((a, b) => a.name.compareTo(b.name));
    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = sorted[i];
        return ListTile(
          title: Text(p.name),
          subtitle: Text('${p.latitude.toStringAsFixed(5)}, '
              '${p.longitude.toStringAsFixed(5)}'
              '${p.accessibilityTags.isEmpty ? '' : ' · ${p.accessibilityTags.join(', ')}'}'),
        );
      },
    );
  }
}

// ─────────────────────────── shared bits ───────────────────────────

class _ColorDot extends StatelessWidget {
  final Color color;
  const _ColorDot(this.color);

  @override
  Widget build(BuildContext context) =>
      Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _DifficultyBadge extends StatelessWidget {
  final int difficulty;
  const _DifficultyBadge(this.difficulty);

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      child: Text('$difficulty', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _Field({required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            style: mono
                ? theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace')
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String message;
  const _Empty(this.message);

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center)));
}
