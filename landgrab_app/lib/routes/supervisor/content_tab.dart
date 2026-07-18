import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/supervisor/pin_action_sheet.dart';
import 'package:landgrab/routes/supervisor/pole_supervision_detail_route.dart';
import 'package:landgrab/routes/supervisor/puzzlet_supervision_detail_route.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/widgets/attachments_badge.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/map_with_bathrooms.dart';
import 'package:landgrab/widgets/status_badge.dart';
import 'package:latlong2/latlong.dart';

enum _ListOrMap { list, map }

enum _Kind { all, poles, puzzlets }

// 'assigned' and 'submitted' are the two review stages that the server
// rolls up into a single `in_review` draft status; we split them here so
// a supervisor can filter "out with a validator" separately from
// "submitted, awaiting my decision".
const _allStatuses = [
  'draft',
  'assigned',
  'submitted',
  'validated',
  'retired'
];

/// One view over poles AND puzzlets — the supervisor mostly cares
/// about "the content", not which table a row lives in. List and map
/// modes with kind + status filters, plus the draw-to-assign flow:
/// trace an area on the map and everything assignable inside it goes
/// to a chosen validator in one batch.
class ContentTab extends StatefulWidget {
  final LandgrabApi api;
  final DashboardCounts? counts;
  final Future<void> Function() onChanged;

  /// Fired when draw mode turns on/off so the host can freeze the
  /// enclosing TabBarView's horizontal swipe — otherwise the tab
  /// pager steals the loop-drawing drag.
  final void Function(bool drawing)? onDrawingChanged;

  const ContentTab({
    super.key,
    required this.api,
    required this.counts,
    required this.onChanged,
    this.onDrawingChanged,
  });

  @override
  State<ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<ContentTab> {
  static const _prefKey = 'supervisor_content';

  // Pin colours. Orange = not yet assigned (needs attention); each
  // active validator gets a distinct palette colour so the map reads
  // as "who's covering what"; validated/retired are muted since
  // they're done. Orange is kept out of the palette so "unassigned"
  // never collides with a validator.
  static const _unassignedColor = Colors.orange;
  static const _validatedColor = Colors.green;
  static const _retiredColor = Colors.blueGrey;
  static const _validatorPalette = <Color>[
    Colors.blue,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
    Colors.deepPurple,
    Color(0xFF827717), // olive
    Colors.redAccent,
  ];

  _ListOrMap _view = _ListOrMap.list;
  _Kind _kind = _Kind.all;
  String? _status; // null = all statuses

  List<DraftPole>? _poles;
  List<DraftPuzzlet>? _puzzlets;
  String? _error;

  // Guards the list's quick-accept buttons so a double-tap (or tapping
  // two rows at once) can't fire overlapping transitions.
  bool _accepting = false;

  // Draw-to-assign state. The polygon persists after the stroke so
  // the supervisor can see what they selected while picking a
  // validator; both clear on assign or cancel.
  bool _drawArmed = false;
  List<LatLng>? _polygon;

  void _armDraw() {
    if (_drawArmed) return;
    setState(() => _drawArmed = true);
    widget.onDrawingChanged?.call(true);
  }

  @override
  void initState() {
    super.initState();
    _loadPref();
    _load();
  }

  Future<void> _loadPref() async {
    final isMap = await UiPreferences.getMapPreferred(_prefKey);
    if (!mounted) return;
    setState(() => _view = isMap ? _ListOrMap.map : _ListOrMap.list);
  }

  void _setView(_ListOrMap v) {
    setState(() => _view = v);
    if (v == _ListOrMap.list) _exitDraw();
    UiPreferences.setMapPreferred(_prefKey, v == _ListOrMap.map);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Everything, one fetch each; kind/status filtering is local so
      // switching chips is instant.
      final results = await Future.wait([
        widget.api.supervisionListPoles(),
        widget.api.supervisionListPuzzlets(),
      ]);
      if (!mounted) return;
      setState(() {
        _poles = results[0] as List<DraftPole>;
        _puzzlets = results[1] as List<DraftPuzzlet>;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  static const _statusByKey = {
    'draft': DraftStatus.draft,
    'validated': DraftStatus.validated,
    'retired': DraftStatus.retired,
  };

  // 'assigned'/'submitted' both sit under DraftStatus.inReview on the
  // draft itself; they're told apart by the active validation's own
  // status, so those two chips filter the review stages separately.
  bool _statusMatches(DraftStatus status, ActiveValidationSummary? validation) {
    if (_status == null) return true;
    if (_status == 'assigned' || _status == 'submitted') {
      return status == DraftStatus.inReview && validation?.status == _status;
    }
    return _statusByKey[_status] == status;
  }

  List<DraftPole> get _visiblePoles => _kind == _Kind.puzzlets
      ? const []
      : (_poles ?? const [])
          .where((p) => _statusMatches(p.status, p.activeValidation))
          .toList();

  List<DraftPuzzlet> get _visiblePuzzlets => _kind == _Kind.poles
      ? const []
      : (_puzzlets ?? const [])
          .where((p) => _statusMatches(p.status, p.activeValidation))
          .toList();

  Future<void> _reloadAll() async {
    await _load();
    await widget.onChanged();
  }

  Future<void> _quickAccept(_ContentRow row) async {
    if (row.accept == null) return;
    setState(() => _accepting = true);
    try {
      await row.accept!(widget.api);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accepted ${row.title}')),
      );
      await _reloadAll();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data?['error']?['detail'] ?? e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept: $detail')),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  // ── Draw-to-assign ─────────────────────────────────────────────

  void _exitDraw() {
    final wasArmed = _drawArmed;
    setState(() {
      _drawArmed = false;
      _polygon = null;
    });
    if (wasArmed) widget.onDrawingChanged?.call(false);
  }

  /// Ray-cast point-in-polygon on raw lat/lng — fine at city scale.
  static bool _inPolygon(double lat, double lng, List<LatLng> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i];
      final b = poly[j];
      if ((a.latitude > lat) != (b.latitude > lat) &&
          lng <
              (b.longitude - a.longitude) *
                      (lat - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool _assignable(DraftStatus status, ActiveValidationSummary? v) =>
      v == null &&
      (status == DraftStatus.draft || status == DraftStatus.inReview);

  Future<void> _onPolygonDrawn(List<LatLng> polygon) async {
    final poles = _visiblePoles
        .where((p) =>
            _assignable(p.status, p.activeValidation) &&
            _inPolygon(p.latitude, p.longitude, polygon))
        .toList();
    final puzzlets = _visiblePuzzlets
        .where((p) =>
            p.latitude != null &&
            // Validator-only puzzlets are set-aside content, not
            // validation work — never selectable for assignment.
            !p.validatorOnly &&
            _assignable(p.status, p.activeValidation) &&
            _inPolygon(p.latitude!, p.longitude!, polygon))
        .toList();

    setState(() => _polygon = polygon);

    if (poles.isEmpty && puzzlets.isEmpty) {
      setState(() => _polygon = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No assignable items in that area '
              '(already assigned or validated ones don\'t count).'),
        ));
      }
      return;
    }

    // Loop so that picking someone who authored everything selected
    // just re-opens the picker (with an explanation) instead of a
    // confusing "all skipped". Nobody validates their own work, so a
    // validator can only take items they didn't create.
    while (mounted) {
      final validator = await _pickValidator(poles.length, puzzlets.length);
      if (validator == null) {
        if (mounted) setState(() => _polygon = null);
        return;
      }

      final assignablePoles =
          poles.where((p) => p.creatorId != validator.id).toList();
      final assignablePuzzlets =
          puzzlets.where((p) => p.creatorId != validator.id).toList();

      if (assignablePoles.isEmpty && assignablePuzzlets.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${validator.name ?? validator.email} authored everything in '
            'that area — nobody validates their own work. Pick someone else.',
          ),
        ));
        continue; // re-open the picker, polygon still shown
      }

      try {
        final result = await widget.api.bulkAssignValidations(
          validatorId: validator.id,
          poleIds: assignablePoles.map((p) => p.id).toList(),
          puzzletIds: assignablePuzzlets.map((p) => p.id).toList(),
        );
        if (!mounted) return;
        _exitDraw();
        final authored = (poles.length + puzzlets.length) -
            (assignablePoles.length + assignablePuzzlets.length);
        final skipped = result.skipped + authored;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Assigned ${result.assigned} to ${validator.name ?? validator.email}'
            '${skipped > 0 ? ' ($skipped skipped)' : ''}',
          ),
        ));
        await _reloadAll();
      } catch (e) {
        if (!mounted) return;
        setState(() => _polygon = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Assignment failed: $e')));
      }
      return;
    }
  }

  Future<ValidatorUser?> _pickValidator(int poleCount, int puzzletCount) {
    return showModalBottomSheet<ValidatorUser>(
      context: context,
      builder: (sheetContext) => _ValidatorPickerSheet(
        api: widget.api,
        poleCount: poleCount,
        puzzletCount: puzzletCount,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<_ListOrMap>(
            segments: const [
              ButtonSegment(
                  value: _ListOrMap.list,
                  label: Text('List'),
                  icon: Icon(Icons.list)),
              ButtonSegment(
                  value: _ListOrMap.map,
                  label: Text('Map'),
                  icon: Icon(Icons.map)),
            ],
            selected: {_view},
            onSelectionChanged: (set) => _setView(set.first),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            for (final kind in _Kind.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(switch (kind) {
                    _Kind.all => 'All',
                    _Kind.poles => 'Poles',
                    _Kind.puzzlets => 'Puzzlets',
                  }),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
              ),
            const SizedBox(height: 24, child: VerticalDivider(width: 16)),
            for (final s in _allStatuses)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(prettifyStatus(s)),
                  selected: _status == s,
                  // Tapping the active chip clears it back to "all".
                  onSelected: (_) =>
                      setState(() => _status = _status == s ? null : s),
                ),
              ),
          ]),
        ),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : (_poles == null || _puzzlets == null)
                  ? const Center(child: CircularProgressIndicator())
                  : _view == _ListOrMap.list
                      ? _buildList()
                      : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final rows = <_ContentRow>[
      for (final p in _visiblePoles) _ContentRow.pole(p),
      for (final p in _visiblePuzzlets) _ContentRow.puzzlet(p),
    ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (rows.isEmpty) return const Center(child: Text('Nothing here.'));

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        return ListTile(
          leading: SizedBox(
            width: 36,
            height: 36,
            child: Icon(row.icon,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          title: Row(children: [
            Expanded(
                child: Text(row.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
            ...row.badges,
          ]),
          subtitle:
              Text(row.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // One-tap accept for clean, submitted validations — saves
              // opening the detail screen just to hit Accept when there's
              // nothing to review.
              if (row.canQuickAccept)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  color: Colors.green,
                  tooltip: 'Accept',
                  onPressed: _accepting ? null : () => _quickAccept(row),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => row.open(context, widget.api, _reloadAll),
        );
      },
    );
  }

  // Builds the validator→colour assignment plus the legend rows for
  // whatever's currently visible. Validators are colour-mapped in a
  // stable order (by display name) so a given validator keeps their
  // colour across rebuilds; only buckets actually present appear in
  // the legend, keeping it small.
  ({Map<String, Color> colorForValidator, List<_LegendEntry> entries})
      _buildLegend() {
    // Distinct validators present, name kept for the label.
    final names = <String, String>{};
    var hasUnassigned = false;
    var hasValidated = false;
    var hasRetired = false;

    void note(DraftStatus status, ActiveValidationSummary? v) {
      final id = v?.validatorId;
      if (id != null) {
        names[id] = v!.validatorName ?? '(unnamed)';
        return;
      }
      switch (status) {
        case DraftStatus.validated:
          hasValidated = true;
        case DraftStatus.retired:
          hasRetired = true;
        default:
          hasUnassigned = true;
      }
    }

    for (final p in _visiblePoles) {
      note(p.status, p.activeValidation);
    }
    for (final p in _visiblePuzzlets) {
      note(p.status, p.activeValidation);
    }

    final ids = names.keys.toList()
      ..sort(
          (a, b) => names[a]!.toLowerCase().compareTo(names[b]!.toLowerCase()));
    final colorForValidator = <String, Color>{};
    final entries = <_LegendEntry>[];
    for (var i = 0; i < ids.length; i++) {
      final color = _validatorPalette[i % _validatorPalette.length];
      colorForValidator[ids[i]] = color;
      entries.add(_LegendEntry(color, names[ids[i]]!));
    }
    if (hasUnassigned) {
      entries.insert(0, const _LegendEntry(_unassignedColor, 'Unassigned'));
    }
    if (hasValidated) {
      entries.add(const _LegendEntry(_validatedColor, 'Validated'));
    }
    if (hasRetired) {
      entries.add(const _LegendEntry(_retiredColor, 'Retired'));
    }

    return (colorForValidator: colorForValidator, entries: entries);
  }

  Widget _buildMap() {
    final legend = _buildLegend();

    Color colorFor(DraftStatus status, ActiveValidationSummary? v) {
      final id = v?.validatorId;
      if (id != null) return legend.colorForValidator[id] ?? _unassignedColor;
      return switch (status) {
        DraftStatus.validated => _validatedColor,
        DraftStatus.retired => _retiredColor,
        _ => _unassignedColor,
      };
    }

    final pins = <MapPin>[
      for (final p in _visiblePoles)
        MapPin.pole(
          position: LatLng(p.latitude, p.longitude),
          label: p.label ?? p.barcode,
          color: colorFor(p.status, p.activeValidation),
          onTap: _drawArmed ? null : () => _onPolePinTap(p),
          accuracyM: p.accuracyM,
        ),
      for (final p in _visiblePuzzlets.where((p) => p.latitude != null))
        MapPin.puzzlet(
          position: LatLng(p.latitude!, p.longitude!),
          label: p.instructions,
          color: colorFor(p.status, p.activeValidation),
          onTap: _drawArmed ? null : () => _onPuzzletPinTap(p),
          regionId: p.regionId,
          starred: p.validatorOnly,
        ),
    ];

    final orphanCount =
        _visiblePuzzlets.where((p) => p.latitude == null).length;

    return Stack(children: [
      Column(children: [
        if (_drawArmed)
          Container(
            width: double.infinity,
            color: Colors.purple.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Draw a loop with one finger to select. '
              'Use two fingers to pan or zoom.',
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: MapWithBathrooms(
            api: widget.api,
            pins: pins,
            editableBathrooms: !_drawArmed,
            drawMode: _drawArmed,
            onPolygonDrawn: _onPolygonDrawn,
            polygon: _polygon,
            cameraMemoryKey: 'supervisor_content_map',
            // Draw-to-assign selects by true position, so plot pins
            // verbatim while lassoing — otherwise the loop wouldn't match
            // what's on screen.
            cluster: !_drawArmed,
            groupByRegion: !_drawArmed,
          ),
        ),
        if (orphanCount > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$orphanCount puzzlet${orphanCount == 1 ? '' : 's'} without a location — see the list view',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ]),
      if (legend.entries.isNotEmpty)
        Positioned(
          top: _drawArmed ? 44 : 8,
          left: 8,
          child: _MapLegend(entries: legend.entries),
        ),
      Positioned(
        right: 12,
        bottom: orphanCount > 0 ? 56 : 12,
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () {
            if (_drawArmed) {
              _exitDraw();
            } else {
              _armDraw();
            }
          },
          icon: Icon(_drawArmed ? Icons.close : Icons.gesture),
          label: Text(_drawArmed ? 'Cancel' : 'Assign area'),
        ),
      ),
    ]);
  }

  Future<void> _onPolePinTap(DraftPole pole) async {
    final result = await showPolePinSheet(
      context,
      api: widget.api,
      pole: pole,
      onUndone: _reloadAll,
    );
    if (result == PinActionResult.changed) await _reloadAll();
  }

  Future<void> _onPuzzletPinTap(DraftPuzzlet puzzlet) async {
    final result = await showPuzzletPinSheet(
      context,
      api: widget.api,
      puzzlet: puzzlet,
      onUndone: _reloadAll,
    );
    if (result == PinActionResult.changed) await _reloadAll();
  }
}

/// A pole or puzzlet flattened into one list row.
class _ContentRow {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final Future<void> Function(
      BuildContext, LandgrabApi, Future<void> Function()) open;

  /// Whether the list can offer a one-tap accept: the validation has
  /// been submitted (so it's the supervisor's to decide) and carries no
  /// comments/suggestions to review first. Null-safe: unassigned items
  /// (no active validation) never qualify.
  final bool canQuickAccept;

  /// Accepts the row's active validation via the right transition
  /// endpoint. Only set when [canQuickAccept] is true.
  final Future<void> Function(LandgrabApi)? accept;

  _ContentRow._(this.icon, this.title, this.subtitle, this.badges, this.open,
      {this.canQuickAccept = false, this.accept});

  static bool _cleanSubmitted(ActiveValidationSummary? v) =>
      v != null && v.status == 'submitted' && v.commentCount == 0;

  factory _ContentRow.pole(DraftPole p) {
    final v = p.activeValidation;
    final canQuickAccept = _cleanSubmitted(v);
    return _ContentRow._(
      Icons.barcode_reader,
      p.label ?? p.barcode,
      'Pole · ${p.barcode}${_assignedTo(v)}',
      _badgesFor(p.status, v, p.attachmentIds.length),
      (context, api, reload) async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                PoleSupervisionDetailRoute(api: api, pole: p, onChanged: reload),
          ),
        );
        if (changed == true) await reload();
      },
      canQuickAccept: canQuickAccept,
      accept: canQuickAccept
          ? (api) async {
              await api.supervisorTransitionPoleValidation(v!.id, 'accepted');
            }
          : null,
    );
  }

  factory _ContentRow.puzzlet(DraftPuzzlet p) {
    final v = p.activeValidation;
    final canQuickAccept = _cleanSubmitted(v);
    return _ContentRow._(
      Icons.question_mark,
      p.instructions,
      'Puzzlet · difficulty ${p.difficulty}'
      '${p.region != null ? ' · ${p.region!.breadcrumb}' : ''}'
      '${_assignedTo(v)}',
      _badgesFor(p.status, v, p.attachmentIds.length),
      (context, api, reload) async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PuzzletSupervisionDetailRoute(
                api: api, puzzlet: p, onChanged: reload),
          ),
        );
        if (changed == true) await reload();
      },
      canQuickAccept: canQuickAccept,
      accept: canQuickAccept
          ? (api) async {
              await api.supervisorTransitionPuzzletValidation(v!.id, 'accepted');
            }
          : null,
    );
  }

  static String _assignedTo(ActiveValidationSummary? v) {
    final name = v?.validatorName;
    return name == null ? '' : ' · $name';
  }

  static List<Widget> _badgesFor(
      DraftStatus status, ActiveValidationSummary? v, int attachmentCount) {
    final tail = <Widget>[
      if (attachmentCount > 0) ...[
        const SizedBox(width: 4),
        AttachmentsBadge(count: attachmentCount),
      ],
    ];
    if (v == null) {
      return [
        StatusBadge(
          label: draftStatusLabel(status),
          color: statusColorFor(draftStatusLabel(status)),
        ),
        ...tail,
      ];
    }
    return [
      StatusBadge(
          label: prettifyStatus(v.status), color: statusColorFor(v.status)),
      if (v.commentCount > 0) ...[
        const SizedBox(width: 4),
        _CommentChip(v.commentCount),
      ],
      ...tail,
    ];
  }
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
          const Icon(Icons.mode_comment_outlined,
              size: 12, color: Colors.purple),
          const SizedBox(width: 2),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: Colors.purple)),
        ],
      ),
    );
  }
}

class _LegendEntry {
  final Color color;
  final String label;
  const _LegendEntry(this.color, this.label);
}

/// Compact translucent legend overlaid on the content map, mapping
/// pin colours to validators (and the unassigned / done buckets).
/// Height-capped so a large validator roster scrolls rather than
/// swallowing the map.
class _MapLegend extends StatelessWidget {
  final List<_LegendEntry> entries;
  const _MapLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180, maxHeight: 180),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 12, color: e.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          e.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidatorPickerSheet extends StatefulWidget {
  final LandgrabApi api;
  final int poleCount;
  final int puzzletCount;

  const _ValidatorPickerSheet({
    required this.api,
    required this.poleCount,
    required this.puzzletCount,
  });

  @override
  State<_ValidatorPickerSheet> createState() => _ValidatorPickerSheetState();
}

class _ValidatorPickerSheetState extends State<_ValidatorPickerSheet> {
  List<ValidatorUser>? _validators;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.listValidators();
      if (mounted) setState(() => _validators = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load validators: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = [
      if (widget.poleCount > 0)
        '${widget.poleCount} pole${widget.poleCount == 1 ? '' : 's'}',
      if (widget.puzzletCount > 0)
        '${widget.puzzletCount} puzzlet${widget.puzzletCount == 1 ? '' : 's'}',
    ].join(' and ');

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Assign $summary to…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!))
          else if (_validators == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_validators!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No validators exist yet.'),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final v in _validators!)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(v.name ?? v.email),
                      subtitle: v.name == null ? null : Text(v.email),
                      onTap: () => Navigator.of(context).pop(v),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
