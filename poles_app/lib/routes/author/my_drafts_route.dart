import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/routes/author/edit_pole_route.dart';
import 'package:poles/routes/author/edit_puzzlet_route.dart';
import 'package:poles/routes/author/promote_to_region_dialog.dart';
import 'package:poles/services/ui_preferences.dart';
import 'package:poles/widgets/attachments_badge.dart';
import 'package:poles/widgets/map_pin.dart';
import 'package:poles/widgets/pin_map.dart';

enum _DraftView { list, map }

class MyDraftsRoute extends StatefulWidget {
  final PolesApi api;
  const MyDraftsRoute({super.key, required this.api});

  @override
  State<MyDraftsRoute> createState() => _MyDraftsRouteState();
}

class _MyDraftsRouteState extends State<MyDraftsRoute> {
  MyDrafts? _drafts;
  String? _error;
  _DraftView _view = _DraftView.list;
  bool _selectionMode = false;
  final Set<String> _selectedPuzzletIds = <String>{};

  static const _prefKey = 'drafts';

  @override
  void initState() {
    super.initState();
    _loadPref();
    _load();
  }

  Future<void> _loadPref() async {
    final isMap = await UiPreferences.getMapPreferred(_prefKey);
    if (!mounted) return;
    setState(() => _view = isMap ? _DraftView.map : _DraftView.list);
  }

  void _setView(_DraftView v) {
    setState(() => _view = v);
    UiPreferences.setMapPreferred(_prefKey, v == _DraftView.map);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drafts = await widget.api.listMyDrafts();
      if (!mounted) return;
      setState(() => _drafts = drafts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load drafts: $e');
    }
  }

  Color _statusColor(DraftStatus s) => switch (s) {
        DraftStatus.draft => Colors.orange.shade700,
        DraftStatus.inReview => Colors.blue.shade700,
        DraftStatus.validated => Colors.green.shade700,
        DraftStatus.retired => Colors.grey.shade700,
      };

  List<MapPin> _pins(MyDrafts drafts) {
    final pins = <MapPin>[];
    for (final p in drafts.poles) {
      final editable = p.status == DraftStatus.draft;
      pins.add(MapPin(
        position: LatLng(p.latitude, p.longitude),
        label: p.label ?? p.barcode,
        icon: Icons.location_on,
        color: _statusColor(p.status),
        onTap: editable ? () => _openPole(p) : null,
      ));
    }
    for (final p in drafts.puzzlets) {
      if (p.latitude != null && p.longitude != null) {
        final editable = p.status == DraftStatus.draft;
        pins.add(MapPin(
          position: LatLng(p.latitude!, p.longitude!),
          label: p.instructions,
          icon: Icons.edit_note,
          color: _statusColor(p.status),
          onTap: editable ? () => _openPuzzlet(p) : null,
        ));
      }
    }
    return pins;
  }

  Future<void> _openPole(DraftPole pole) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPoleRoute(api: widget.api, pole: pole)),
    );
    if (changed == true) await _load();
  }

  Future<void> _openPuzzlet(DraftPuzzlet puzzlet) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPuzzletRoute(api: widget.api, puzzlet: puzzlet)),
    );
    if (changed == true) await _load();
  }

  int _puzzletsWithoutLocation(MyDrafts drafts) =>
      drafts.puzzlets.where((p) => p.latitude == null).length;

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedPuzzletIds.clear();
      // Selection only works in list view; force it.
      _view = _DraftView.list;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPuzzletIds.clear();
    });
  }

  void _toggleSelected(String puzzletId) {
    setState(() {
      if (!_selectedPuzzletIds.add(puzzletId)) {
        _selectedPuzzletIds.remove(puzzletId);
      }
    });
  }

  Future<void> _promote() async {
    final drafts = _drafts;
    if (drafts == null) return;
    final selected = drafts.puzzlets
        .where((p) => _selectedPuzzletIds.contains(p.id))
        .toList(growable: false);
    if (selected.isEmpty) return;

    final result = await showDialog<PromoteResult>(
      context: context,
      builder: (_) =>
          PromoteToRegionDialog(api: widget.api, puzzlets: selected),
    );
    if (!mounted) return;
    if (result == null) return;

    final failed = result.failedPuzzletIds.length;
    final msg = failed == 0
        ? 'Created region "${result.region.name}" and assigned ${result.assignedCount} puzzlet${result.assignedCount == 1 ? '' : 's'}.'
        : 'Region created. ${result.assignedCount} assigned; $failed failed.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    _exitSelectionMode();
    await _load();
  }

  PreferredSizeWidget _appBar() {
    if (_selectionMode) {
      final canPromote = _selectedPuzzletIds.isNotEmpty;
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitSelectionMode,
        ),
        title: Text(_selectedPuzzletIds.isEmpty
            ? 'Select puzzlets'
            : '${_selectedPuzzletIds.length} selected'),
        actions: [
          TextButton.icon(
            onPressed: canPromote ? _promote : null,
            icon: const Icon(Icons.merge_type),
            label: const Text('Group'),
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('My drafts'),
      actions: [
        IconButton(
          tooltip: 'Select puzzlets to group into a region',
          onPressed: _enterSelectionMode,
          icon: const Icon(Icons.check_circle_outline),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<_DraftView>(
            segments: const [
              ButtonSegment(
                  value: _DraftView.list,
                  label: Text('List'),
                  icon: Icon(Icons.list)),
              ButtonSegment(
                  value: _DraftView.map,
                  label: Text('Map'),
                  icon: Icon(Icons.map)),
            ],
            selected: {_view},
            onSelectionChanged: (set) => _setView(set.first),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    return Scaffold(
      appBar: _appBar(),
      body: _error != null
          ? Center(child: Text(_error!))
          : drafts == null
              ? const Center(child: CircularProgressIndicator())
              : _view == _DraftView.list
                  ? _ListView(
                      drafts: drafts,
                      api: widget.api,
                      onChanged: _load,
                      selectionMode: _selectionMode,
                      selectedPuzzletIds: _selectedPuzzletIds,
                      onTogglePuzzletSelected: _toggleSelected,
                    )
                  : _MapView(
                      pins: _pins(drafts),
                      orphanCount: _puzzletsWithoutLocation(drafts),
                    ),
    );
  }
}

class _ListView extends StatelessWidget {
  final MyDrafts drafts;
  final PolesApi api;
  final Future<void> Function() onChanged;
  final bool selectionMode;
  final Set<String> selectedPuzzletIds;
  final ValueChanged<String>? onTogglePuzzletSelected;

  const _ListView({
    required this.drafts,
    required this.api,
    required this.onChanged,
    this.selectionMode = false,
    this.selectedPuzzletIds = const <String>{},
    this.onTogglePuzzletSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (drafts.poles.isEmpty && drafts.puzzlets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nothing yet. Capture a pole or puzzlet.')),
          ),
        if (drafts.puzzlets.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Puzzlets', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ...drafts.puzzlets.map((p) => _PuzzletTile(
              puzzlet: p,
              api: api,
              onChanged: onChanged,
              selectionMode: selectionMode,
              selected: selectedPuzzletIds.contains(p.id),
              onToggleSelected: onTogglePuzzletSelected,
            )),
        // Poles are hidden in selection mode — promotion is puzzlet-only.
        if (!selectionMode && drafts.poles.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Poles', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        if (!selectionMode)
          ...drafts.poles
              .map((p) => _PoleTile(pole: p, api: api, onChanged: onChanged)),
      ],
    );
  }
}

class _MapView extends StatelessWidget {
  final List<MapPin> pins;
  final int orphanCount;
  const _MapView({required this.pins, required this.orphanCount});

  @override
  Widget build(BuildContext context) {
    if (pins.isEmpty && orphanCount == 0) {
      return const Center(child: Text('No drafts to show on a map.'));
    }
    return Column(
      children: [
        Expanded(
          child: pins.isEmpty
              ? const Center(child: Text('No drafts have a captured location yet.'))
              : PinMap(pins: pins),
        ),
        if (orphanCount > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$orphanCount puzzlet${orphanCount == 1 ? '' : 's'} without a location',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final DraftStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DraftStatus.draft => ('draft', Colors.orange.shade700),
      DraftStatus.inReview => ('in_review', Colors.blue.shade700),
      DraftStatus.validated => ('validated', Colors.green.shade700),
      DraftStatus.retired => ('retired', Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

class _PoleTile extends StatelessWidget {
  final DraftPole pole;
  final PolesApi api;
  final Future<void> Function() onChanged;
  const _PoleTile({required this.pole, required this.api, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final editable = pole.status == DraftStatus.draft;
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(pole.label ?? pole.barcode)),
          _StatusBadge(pole.status),
          if (pole.attachmentIds.isNotEmpty) ...[
            const SizedBox(width: 4),
            AttachmentsBadge(count: pole.attachmentIds.length),
          ],
        ],
      ),
      subtitle: Text(
        '${pole.barcode}\n'
        '${pole.latitude.toStringAsFixed(5)}, ${pole.longitude.toStringAsFixed(5)}'
        '${pole.accuracyM != null ? ' · ±${pole.accuracyM!.toStringAsFixed(0)} m' : ''}',
      ),
      isThreeLine: true,
      trailing: editable ? const Icon(Icons.chevron_right) : null,
      onTap: editable
          ? () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => EditPoleRoute(api: api, pole: pole),
                ),
              );
              if (changed == true) await onChanged();
            }
          : null,
    );
  }
}

class _PuzzletTile extends StatelessWidget {
  final DraftPuzzlet puzzlet;
  final PolesApi api;
  final Future<void> Function() onChanged;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<String>? onToggleSelected;

  const _PuzzletTile({
    required this.puzzlet,
    required this.api,
    required this.onChanged,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final editable = puzzlet.status == DraftStatus.draft;
    final tile = ListTile(
      leading: selectionMode
          ? Checkbox(
              value: selected,
              onChanged: editable
                  ? (_) => onToggleSelected?.call(puzzlet.id)
                  : null,
            )
          : null,
      title: Row(
        children: [
          Expanded(
            child: Text(
              puzzlet.instructions,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _StatusBadge(puzzlet.status),
          if (puzzlet.attachmentIds.isNotEmpty) ...[
            const SizedBox(width: 4),
            AttachmentsBadge(count: puzzlet.attachmentIds.length),
          ],
        ],
      ),
      subtitle: Text(
        '${puzzlet.region != null ? 'In ${puzzlet.region!.breadcrumb} · ' : ''}'
        'Answer: ${puzzlet.answer} · Difficulty ${puzzlet.difficulty}'
        '${puzzlet.poleId == null ? ' · unassigned' : ''}'
        '${puzzlet.latitude != null ? '\n${puzzlet.latitude!.toStringAsFixed(5)}, ${puzzlet.longitude!.toStringAsFixed(5)}${puzzlet.accuracyM != null ? ' · ±${puzzlet.accuracyM!.toStringAsFixed(0)} m' : ''}' : ''}',
      ),
      isThreeLine: puzzlet.latitude != null || puzzlet.region != null,
      trailing: selectionMode
          ? null
          : editable
              ? const Icon(Icons.chevron_right)
              : null,
      onTap: selectionMode
          ? (editable ? () => onToggleSelected?.call(puzzlet.id) : null)
          : (editable
              ? () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => EditPuzzletRoute(api: api, puzzlet: puzzlet),
                    ),
                  );
                  if (changed == true) await onChanged();
                }
              : null),
    );
    return tile;
  }
}
