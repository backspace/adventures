import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/widgets/status_badge.dart';
import 'package:latlong2/latlong.dart';

/// Supervisor-side pole↔puzzlet attachment management. This is the
/// supervisor mirror of the author's pole/puzzlet sheets in
/// authoring_map_route.dart: the author phase is ending but validation
/// runs on, so a supervisor needs to (re)attach puzzlets to poles the
/// same way — and on not-yet-validated (draft/in-review) items, not just
/// validated ones. It writes through the supervisor endpoint
/// (`supervisorEditPuzzlet`, which permits pole_id at any status) rather
/// than the author draft endpoint.

const double _nearbyRadiusMetres = 500;
const int _nearbyCap = 30;

// Retired/withdrawn content is off the game; never offer it as an
// attach target or candidate — but keep showing it if it's somehow
// already attached, so it can be detached.
bool _live(DraftStatus s) =>
    s != DraftStatus.retired && s != DraftStatus.withdrawn;

/// Pole-centric: what's attached here, plus nearby unattached puzzlets to
/// pull in. Returns true if any attachment changed (so the caller reloads).
Future<bool> showSupervisorPoleAttachments(
  BuildContext context, {
  required LandgrabApi api,
  required DraftPole pole,
  required List<DraftPuzzlet> allPuzzlets,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PoleAttachmentsSheet(
      api: api,
      pole: pole,
      allPuzzlets: allPuzzlets,
    ),
  );
  return changed ?? false;
}

/// Puzzlet-centric: the pole this puzzlet is on (detach), plus nearby poles
/// to move it to. Returns true if the attachment changed.
Future<bool> showSupervisorPuzzletPole(
  BuildContext context, {
  required LandgrabApi api,
  required DraftPuzzlet puzzlet,
  required List<DraftPole> allPoles,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PuzzletPoleSheet(
      api: api,
      puzzlet: puzzlet,
      allPoles: allPoles,
    ),
  );
  return changed ?? false;
}

class _PoleAttachmentsSheet extends StatefulWidget {
  final LandgrabApi api;
  final DraftPole pole;
  final List<DraftPuzzlet> allPuzzlets;

  const _PoleAttachmentsSheet({
    required this.api,
    required this.pole,
    required this.allPuzzlets,
  });

  @override
  State<_PoleAttachmentsSheet> createState() => _PoleAttachmentsSheetState();
}

class _PoleAttachmentsSheetState extends State<_PoleAttachmentsSheet> {
  // Local mutable copy so attach/detach move rows between the two lists
  // live, without a round-trip reload between each tap.
  late final List<DraftPuzzlet> _puzzlets = List.of(widget.allPuzzlets);
  final Set<String> _busy = {};
  bool _changed = false;
  bool _showAll = false;

  List<DraftPuzzlet> get _attached =>
      _puzzlets.where((p) => p.poleId == widget.pole.id).toList();

  /// Unattached, live puzzlets. Located ones are sorted by distance from
  /// the pole; when [_showAll] is on, location-less ones follow at the end
  /// so orphans captured without a fix can still be pulled in.
  List<(DraftPuzzlet, double?)> get _candidates {
    final anchor = LatLng(widget.pole.latitude, widget.pole.longitude);
    const distance = Distance();
    final located = <(DraftPuzzlet, double)>[];
    final unlocated = <DraftPuzzlet>[];
    for (final p in _puzzlets) {
      // Skip anything already attached, off the game (retired/withdrawn), or
      // validator-only — validator-only puzzlets are set-aside content, never
      // offered as new player-facing wiring (matching the attachments map).
      if (p.poleId != null || !_live(p.status) || p.validatorOnly) continue;
      if (p.latitude == null || p.longitude == null) {
        unlocated.add(p);
        continue;
      }
      final d = distance.as(
          LengthUnit.Meter, anchor, LatLng(p.latitude!, p.longitude!));
      if (_showAll || d <= _nearbyRadiusMetres) located.add((p, d));
    }
    located.sort((a, b) => a.$2.compareTo(b.$2));
    return [
      for (final (p, d) in located) (p, d),
      if (_showAll)
        for (final p in unlocated) (p, null),
    ];
  }

  int get _totalUnattached => _puzzlets
      .where((p) => p.poleId == null && _live(p.status) && !p.validatorOnly)
      .length;

  Future<void> _attach(DraftPuzzlet p) =>
      _run(p, () => widget.api.supervisorEditPuzzlet(p.id, poleId: widget.pole.id));

  Future<void> _detach(DraftPuzzlet p) =>
      _run(p, () => widget.api.supervisorEditPuzzlet(p.id, clearPole: true));

  Future<void> _run(
      DraftPuzzlet p, Future<DraftPuzzlet> Function() call) async {
    setState(() => _busy.add(p.id));
    try {
      final updated = await call();
      if (!mounted) return;
      final i = _puzzlets.indexWhere((x) => x.id == updated.id);
      setState(() {
        if (i >= 0) _puzzlets[i] = updated;
        _changed = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $detail')));
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attached = _attached;
    final candidates = _candidates;
    final hasMore = _totalUnattached > candidates.length;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.pole.label ?? widget.pole.barcode,
                    style: theme.textTheme.titleLarge),
                Text('Barcode: ${widget.pole.barcode}',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
                Text('Attached puzzlets · ${attached.length}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (attached.isEmpty)
                  Text('None yet. Attach from the list below.',
                      style: theme.textTheme.bodyMedium)
                else
                  for (final p in attached)
                    _PuzzletLine(
                      puzzlet: p,
                      distanceM: null,
                      busy: _busy.contains(p.id),
                      action: 'Detach',
                      onAction: () => _detach(p),
                    ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showAll
                            ? 'All unattached'
                            : 'Nearby unattached · within '
                                '${_nearbyRadiusMetres.toInt()} m',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (hasMore || _showAll)
                      TextButton(
                        onPressed: () => setState(() => _showAll = !_showAll),
                        child: Text(_showAll
                            ? 'Nearby only'
                            : 'Show all ($_totalUnattached)'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (candidates.isEmpty)
                  Text(
                    _totalUnattached == 0
                        ? 'No unattached puzzlets.'
                        : 'None within this radius. Tap "Show all".',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final (p, d) in candidates.take(_nearbyCap))
                    _PuzzletLine(
                      puzzlet: p,
                      distanceM: d,
                      busy: _busy.contains(p.id),
                      action: 'Attach',
                      onAction: () => _attach(p),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PuzzletPoleSheet extends StatefulWidget {
  final LandgrabApi api;
  final DraftPuzzlet puzzlet;
  final List<DraftPole> allPoles;

  const _PuzzletPoleSheet({
    required this.api,
    required this.puzzlet,
    required this.allPoles,
  });

  @override
  State<_PuzzletPoleSheet> createState() => _PuzzletPoleSheetState();
}

class _PuzzletPoleSheetState extends State<_PuzzletPoleSheet> {
  late DraftPuzzlet _puzzlet = widget.puzzlet;
  bool _busy = false;
  bool _changed = false;

  DraftPole? get _attachedPole {
    final id = _puzzlet.poleId;
    if (id == null) return null;
    for (final pole in widget.allPoles) {
      if (pole.id == id) return pole;
    }
    return null;
  }

  /// Nearby poles that aren't the current attachment, sorted by distance.
  /// Requires the puzzlet to have a location; poles without a location
  /// don't exist (every pole is staked), so only the puzzlet gates this.
  List<(DraftPole, double)> get _nearbyPoles {
    if (_puzzlet.latitude == null || _puzzlet.longitude == null) {
      return const [];
    }
    const distance = Distance();
    final anchor = LatLng(_puzzlet.latitude!, _puzzlet.longitude!);
    final entries = <(DraftPole, double)>[];
    for (final pole in widget.allPoles) {
      if (pole.id == _puzzlet.poleId || !_live(pole.status)) continue;
      final d = distance.as(
          LengthUnit.Meter, anchor, LatLng(pole.latitude, pole.longitude));
      if (d <= _nearbyRadiusMetres) entries.add((pole, d));
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    return entries;
  }

  Future<void> _attach(DraftPole pole) =>
      _run(() => widget.api.supervisorEditPuzzlet(_puzzlet.id, poleId: pole.id));

  Future<void> _detach() =>
      _run(() => widget.api.supervisorEditPuzzlet(_puzzlet.id, clearPole: true));

  Future<void> _run(Future<DraftPuzzlet> Function() call) async {
    setState(() => _busy = true);
    try {
      final updated = await call();
      if (!mounted) return;
      setState(() {
        _puzzlet = updated;
        _changed = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $detail')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pole = _attachedPole;
    final nearby = _nearbyPoles;
    final noLocation =
        _puzzlet.latitude == null || _puzzlet.longitude == null;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_puzzlet.instructions, style: theme.textTheme.titleLarge),
                if (_puzzlet.region != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 16, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _puzzlet.region!.breadcrumb,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text('Attached to', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (pole == null)
                  Text('Not attached to any pole.',
                      style: theme.textTheme.bodyMedium)
                else
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.sensors),
                      title: Text(pole.label ?? pole.barcode),
                      subtitle: Text(pole.barcode),
                      trailing: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : OutlinedButton(
                              onPressed: _detach,
                              child: const Text('Detach'),
                            ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Nearby poles · within ${_nearbyRadiusMetres.toInt()} m',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (noLocation)
                  Text(
                    'This puzzlet has no location, so nearby poles can\'t be '
                    'listed. Attach it from the pole instead.',
                    style: theme.textTheme.bodyMedium,
                  )
                else if (nearby.isEmpty)
                  Text('No poles within this radius.',
                      style: theme.textTheme.bodyMedium)
                else
                  for (final (candidate, d) in nearby.take(_nearbyCap))
                    _PoleLine(
                      pole: candidate,
                      distanceM: d,
                      busy: _busy,
                      onAttach: () => _attach(candidate),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _distanceLabel(double? m) {
  if (m == null) return 'no location';
  if (m < 1000) return '${m.round()} m';
  return '${(m / 1000).toStringAsFixed(1)} km';
}

class _PuzzletLine extends StatelessWidget {
  final DraftPuzzlet puzzlet;
  final double? distanceM;
  final bool busy;
  final String action;
  final VoidCallback onAction;

  const _PuzzletLine({
    required this.puzzlet,
    required this.distanceM,
    required this.busy,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = draftStatusLabel(puzzlet.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(puzzlet.instructions,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StatusBadge(
                        label: label,
                        color: statusColorFor(label),
                        dense: true),
                    const SizedBox(width: 6),
                    Text(
                      'difficulty ${puzzlet.difficulty}'
                      '${distanceM != null ? ' · ${_distanceLabel(distanceM)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

class _PoleLine extends StatelessWidget {
  final DraftPole pole;
  final double distanceM;
  final bool busy;
  final VoidCallback onAttach;

  const _PoleLine({
    required this.pole,
    required this.distanceM,
    required this.busy,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final label = draftStatusLabel(pole.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pole.label ?? pole.barcode,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    StatusBadge(
                        label: label,
                        color: statusColorFor(label),
                        dense: true),
                    const SizedBox(width: 6),
                    Text('${_distanceLabel(distanceM)} away',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton(onPressed: onAttach, child: const Text('Attach')),
        ],
      ),
    );
  }
}
