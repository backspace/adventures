import 'package:flutter/material.dart';

import 'package:landgrab/viewer/viewer_dataset.dart';

/// Read-only browser over an imported [ViewerDataset]. No API, no game state —
/// just the content, grouped for reading. This is the "viewer" the whole
/// device-to-device flow exists to feed.
class ViewerBrowseRoute extends StatelessWidget {
  final ViewerDataset dataset;
  const ViewerBrowseRoute({super.key, required this.dataset});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Puzzlets (${dataset.puzzlets.length})'),
              Tab(text: 'Regions (${dataset.regions.length})'),
              Tab(text: 'Stakes (${dataset.poles.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PuzzletList(dataset: dataset),
            _RegionList(regions: dataset.regions),
            _PoleList(poles: dataset.poles),
          ],
        ),
      ),
    );
  }
}

class _PuzzletList extends StatelessWidget {
  final ViewerDataset dataset;
  const _PuzzletList({required this.dataset});

  @override
  Widget build(BuildContext context) {
    final regionName = {for (final r in dataset.regions) r.id: r.name};
    final poleName = {for (final p in dataset.poles) p.id: p.name};
    final puzzlets = [...dataset.puzzlets]
      ..sort((a, b) => a.difficulty.compareTo(b.difficulty));

    if (puzzlets.isEmpty) return const _Empty('No puzzlets in this bundle.');
    return ListView.separated(
      itemCount: puzzlets.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = puzzlets[i];
        return ExpansionTile(
          leading: _DifficultyBadge(p.difficulty),
          title: Text(
            p.instructions.isEmpty ? '(no instructions)' : p.instructions,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_subtitle(p, regionName, poleName)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _Field(label: 'Instructions', value: p.instructions),
            _Field(label: 'Answer', value: p.answer, mono: true),
            _Field(label: 'Answer type', value: p.answerType),
            if (p.regionId != null)
              _Field(label: 'Region', value: regionName[p.regionId] ?? p.regionId!),
            if (p.poleId != null)
              _Field(label: 'Stake', value: poleName[p.poleId] ?? p.poleId!),
          ],
        );
      },
    );
  }

  String _subtitle(
    ViewerPuzzlet p,
    Map<String, String> regionName,
    Map<String, String> poleName,
  ) {
    final bits = <String>[p.answerType];
    if (p.regionId != null) bits.add(regionName[p.regionId] ?? '?');
    return bits.join(' · ');
  }
}

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
        return ListTile(
          title: Text(r.name),
          subtitle: (r.entryInstructions ?? '').isEmpty
              ? null
              : Text(r.entryInstructions!),
          isThreeLine: (r.entryInstructions ?? '').isNotEmpty,
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
      padding: const EdgeInsets.only(top: 8),
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
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(message)));
}
