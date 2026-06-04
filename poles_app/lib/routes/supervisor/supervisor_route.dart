import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/routes/supervisor/pin_action_sheet.dart';
import 'package:poles/routes/supervisor/pole_supervision_detail_route.dart';
import 'package:poles/routes/supervisor/puzzlet_supervision_detail_route.dart';
import 'package:poles/services/ui_preferences.dart';
import 'package:poles/widgets/map_pin.dart';
import 'package:poles/widgets/pin_map.dart';
import 'package:poles/widgets/attachments_badge.dart';
import 'package:poles/widgets/status_badge.dart';

enum _ListOrMap { list, map }

List<Widget> _poleBadges(DraftPole p) {
  final v = p.activeValidation;
  final attachmentCount = p.attachmentIds.length;
  final tail = <Widget>[
    if (attachmentCount > 0) ...[
      const SizedBox(width: 4),
      AttachmentsBadge(count: attachmentCount),
    ],
  ];
  if (v == null) {
    return [
      StatusBadge(
        label: draftStatusLabel(p.status),
        color: statusColorFor(draftStatusLabel(p.status)),
      ),
      ...tail,
    ];
  }
  return [
    StatusBadge(label: prettifyStatus(v.status), color: statusColorFor(v.status)),
    if (v.commentCount > 0) ...[
      const SizedBox(width: 4),
      _CommentChip(v.commentCount),
    ],
    ...tail,
  ];
}

List<Widget> _puzzletBadges(DraftPuzzlet p) {
  final v = p.activeValidation;
  final attachmentCount = p.attachmentIds.length;
  final tail = <Widget>[
    if (attachmentCount > 0) ...[
      const SizedBox(width: 4),
      AttachmentsBadge(count: attachmentCount),
    ],
  ];
  if (v == null) {
    return [
      StatusBadge(
        label: draftStatusLabel(p.status),
        color: statusColorFor(draftStatusLabel(p.status)),
      ),
      ...tail,
    ];
  }
  return [
    StatusBadge(label: prettifyStatus(v.status), color: statusColorFor(v.status)),
    if (v.commentCount > 0) ...[
      const SizedBox(width: 4),
      _CommentChip(v.commentCount),
    ],
    ...tail,
  ];
}

class _CommentChip extends StatelessWidget {
  final int count;
  const _CommentChip(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.15),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mode_comment_outlined, size: 12, color: Colors.purple),
          const SizedBox(width: 2),
          Text('$count', style: const TextStyle(fontSize: 12, color: Colors.purple)),
        ],
      ),
    );
  }
}

class SupervisorRoute extends StatefulWidget {
  final PolesApi api;
  const SupervisorRoute({super.key, required this.api});

  @override
  State<SupervisorRoute> createState() => _SupervisorRouteState();
}

class _SupervisorRouteState extends State<SupervisorRoute> {
  DashboardCounts? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final counts = await widget.api.supervisorDashboard();
      if (!mounted) return;
      setState(() => _counts = counts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load dashboard: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supervision'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Puzzlets'),
            Tab(text: 'Poles'),
          ]),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: TabBarView(children: [
          _Overview(counts: _counts, error: _error),
          _PuzzletsTab(api: widget.api, counts: _counts, onChanged: _load),
          _PolesTab(api: widget.api, counts: _counts, onChanged: _load),
        ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final DashboardCounts? counts;
  final String? error;

  const _Overview({required this.counts, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (counts == null) return const Center(child: CircularProgressIndicator());

    final submittedTotal = counts!.poleValidationsSubmitted + counts!.puzzletValidationsSubmitted;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (submittedTotal > 0)
          Card(
            color: Colors.purple.shade50,
            child: ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Colors.purple),
              title: Text(
                '$submittedTotal awaiting your review',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${counts!.poleValidationsSubmitted} pole · '
                '${counts!.puzzletValidationsSubmitted} puzzlet',
              ),
            ),
          ),
        if (submittedTotal > 0) const SizedBox(height: 16),
        _Section('Puzzlets by status', counts!.puzzlets),
        const SizedBox(height: 16),
        _Section('Poles by status', counts!.poles),
        const SizedBox(height: 16),
        _Section('Puzzlet validations', counts!.puzzletValidations),
        const SizedBox(height: 16),
        _Section('Pole validations', counts!.poleValidations),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Map<String, int> counts;

  const _Section(this.title, this.counts);

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (entries.isEmpty) const Text('Nothing yet.'),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    StatusBadge(label: prettifyStatus(e.key), color: statusColorFor(e.key)),
                    const SizedBox(width: 12),
                    Text('${e.value}'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _allPoleStatuses = ['draft', 'in_review', 'validated', 'retired'];

class _PolesTab extends StatefulWidget {
  final PolesApi api;
  final DashboardCounts? counts;
  final Future<void> Function() onChanged;

  const _PolesTab({
    required this.api,
    required this.counts,
    required this.onChanged,
  });

  @override
  State<_PolesTab> createState() => _PolesTabState();
}

class _PolesTabState extends State<_PolesTab> {
  static const _prefKey = 'supervisor_poles';
  // Null until counts are available; once chosen (either from counts or
  // by the user) we never revert it.
  String? _filter;
  _ListOrMap _view = _ListOrMap.list;
  List<DraftPole>? _poles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPref();
    _maybeAdoptInitialFilter();
  }

  @override
  void didUpdateWidget(_PolesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAdoptInitialFilter();
  }

  /// Picks the first status with at least one pole as the initial filter
  /// (so the supervisor doesn't land on an empty "draft" list when
  /// everything sits in `in_review`, say). Only runs while `_filter` is
  /// still null, so it can't clobber a user-chosen filter on rebuild.
  void _maybeAdoptInitialFilter() {
    if (_filter != null) return;
    final counts = widget.counts;
    if (counts == null) return;
    final chosen = _allPoleStatuses.firstWhere(
      (s) => (counts.poles[s] ?? 0) > 0,
      orElse: () => 'draft',
    );
    setState(() => _filter = chosen);
    _load();
  }

  Future<void> _loadPref() async {
    final isMap = await UiPreferences.getMapPreferred(_prefKey);
    if (!mounted) return;
    setState(() => _view = isMap ? _ListOrMap.map : _ListOrMap.list);
  }

  void _setView(_ListOrMap v) {
    setState(() => _view = v);
    UiPreferences.setMapPreferred(_prefKey, v == _ListOrMap.map);
  }

  Future<void> _load() async {
    final filter = _filter;
    if (filter == null) return;
    setState(() => _error = null);
    try {
      final list = await widget.api.supervisionListPoles(status: filter);
      if (!mounted) return;
      setState(() => _poles = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _onPinTap(DraftPole pole) async {
    final result = await showPolePinSheet(
      context,
      api: widget.api,
      pole: pole,
      onUndone: () async {
        await _load();
        await widget.onChanged();
      },
    );
    if (result == PinActionResult.changed) {
      await _load();
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<_ListOrMap>(
            segments: const [
              ButtonSegment(value: _ListOrMap.list, label: Text('List'), icon: Icon(Icons.list)),
              ButtonSegment(value: _ListOrMap.map, label: Text('Map'), icon: Icon(Icons.map)),
            ],
            selected: {_view},
            onSelectionChanged: (set) => _setView(set.first),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: _allPoleStatuses
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(prettifyStatus(s)),
                        selected: _filter == s,
                        onSelected: (_) {
                          setState(() => _filter = s);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : _poles == null
                  ? const Center(child: CircularProgressIndicator())
                  : _poles!.isEmpty
                      ? const Center(child: Text('Nothing here.'))
                      : _view == _ListOrMap.list
                          ? _buildList()
                          : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _poles!.length,
      itemBuilder: (_, i) {
        final p = _poles![i];
        return ListTile(
          title: Row(
            children: [
              Expanded(child: Text(p.label ?? p.barcode)),
              ..._poleBadges(p),
            ],
          ),
          subtitle: Text(p.barcode),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PoleSupervisionDetailRoute(
                  api: widget.api,
                  pole: p,
                ),
              ),
            );
            if (changed == true) {
              await _load();
              await widget.onChanged();
            }
          },
        );
      },
    );
  }

  Widget _buildMap() {
    final pins = _poles!
        .map((p) => MapPin(
              position: LatLng(p.latitude, p.longitude),
              label: p.label ?? p.barcode,
              icon: Icons.location_on,
              color: statusColorFor(draftStatusLabel(p.status)),
              onTap: () => _onPinTap(p),
            ))
        .toList();
    return PinMap(pins: pins);
  }
}

const _allPuzzletStatuses = ['draft', 'in_review', 'validated', 'retired'];

class _PuzzletsTab extends StatefulWidget {
  final PolesApi api;
  final DashboardCounts? counts;
  final Future<void> Function() onChanged;

  const _PuzzletsTab({
    required this.api,
    required this.counts,
    required this.onChanged,
  });

  @override
  State<_PuzzletsTab> createState() => _PuzzletsTabState();
}

class _PuzzletsTabState extends State<_PuzzletsTab> {
  static const _prefKey = 'supervisor_puzzlets';
  String? _filter;
  _ListOrMap _view = _ListOrMap.list;
  List<DraftPuzzlet>? _puzzlets;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPref();
    _maybeAdoptInitialFilter();
  }

  @override
  void didUpdateWidget(_PuzzletsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAdoptInitialFilter();
  }

  void _maybeAdoptInitialFilter() {
    if (_filter != null) return;
    final counts = widget.counts;
    if (counts == null) return;
    final chosen = _allPuzzletStatuses.firstWhere(
      (s) => (counts.puzzlets[s] ?? 0) > 0,
      orElse: () => 'draft',
    );
    setState(() => _filter = chosen);
    _load();
  }

  Future<void> _loadPref() async {
    final isMap = await UiPreferences.getMapPreferred(_prefKey);
    if (!mounted) return;
    setState(() => _view = isMap ? _ListOrMap.map : _ListOrMap.list);
  }

  void _setView(_ListOrMap v) {
    setState(() => _view = v);
    UiPreferences.setMapPreferred(_prefKey, v == _ListOrMap.map);
  }

  Future<void> _load() async {
    final filter = _filter;
    if (filter == null) return;
    setState(() => _error = null);
    try {
      final list = await widget.api.supervisionListPuzzlets(status: filter);
      if (!mounted) return;
      setState(() => _puzzlets = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _onPinTap(DraftPuzzlet p) async {
    final result = await showPuzzletPinSheet(
      context,
      api: widget.api,
      puzzlet: p,
      onUndone: () async {
        await _load();
        await widget.onChanged();
      },
    );
    if (result == PinActionResult.changed) {
      await _load();
      await widget.onChanged();
    }
  }

  int _orphanCount() =>
      _puzzlets?.where((p) => p.latitude == null).length ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_filter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<_ListOrMap>(
            segments: const [
              ButtonSegment(value: _ListOrMap.list, label: Text('List'), icon: Icon(Icons.list)),
              ButtonSegment(value: _ListOrMap.map, label: Text('Map'), icon: Icon(Icons.map)),
            ],
            selected: {_view},
            onSelectionChanged: (set) => _setView(set.first),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: _allPuzzletStatuses
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(prettifyStatus(s)),
                        selected: _filter == s,
                        onSelected: (_) {
                          setState(() => _filter = s);
                          _load();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : _puzzlets == null
                  ? const Center(child: CircularProgressIndicator())
                  : _puzzlets!.isEmpty
                      ? const Center(child: Text('Nothing here.'))
                      : _view == _ListOrMap.list
                          ? _buildList()
                          : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: _puzzlets!.length,
      itemBuilder: (_, i) {
        final p = _puzzlets![i];
        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  p.instructions,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ..._puzzletBadges(p),
            ],
          ),
          subtitle: Text(
            '${p.region != null ? 'In ${p.region!.breadcrumb} · ' : ''}'
            'Difficulty ${p.difficulty} · Answer: ${p.answer}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => PuzzletSupervisionDetailRoute(
                  api: widget.api,
                  puzzlet: p,
                ),
              ),
            );
            if (changed == true) {
              await _load();
              await widget.onChanged();
            }
          },
        );
      },
    );
  }

  Widget _buildMap() {
    final located = _puzzlets!.where((p) => p.latitude != null).toList();
    final pins = located
        .map((p) => MapPin(
              position: LatLng(p.latitude!, p.longitude!),
              label: p.instructions,
              icon: Icons.edit_note,
              color: statusColorFor(draftStatusLabel(p.status)),
              onTap: () => _onPinTap(p),
            ))
        .toList();

    final orphan = _orphanCount();
    return Column(
      children: [
        Expanded(
          child: pins.isEmpty
              ? const Center(child: Text('No puzzlets with a captured location.'))
              : PinMap(pins: pins),
        ),
        if (orphan > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$orphan puzzlet${orphan == 1 ? '' : 's'} without a location — see the list view',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
