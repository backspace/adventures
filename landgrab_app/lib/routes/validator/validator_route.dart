import 'package:flutter/material.dart';
import 'package:landgrab/widgets/scroll_insets.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/validator/pole_validation_interstitial_route.dart';
import 'package:landgrab/routes/validator/puzzlet_validation_interstitial_route.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/widgets/attachments_badge.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/map_with_bathrooms.dart';
import 'package:landgrab/widgets/markdown_view.dart';
import 'package:landgrab/widgets/status_badge.dart';

enum _ValidatorView { list, map, criteria }

enum _Kind { all, poles, puzzlets }

/// Within-group ordering for the to-do list. Needs-action rank is always the
/// top grouping (see `_actionRank`); this picks the key applied *inside* each
/// group, with distance the tiebreak either way.
enum _Sort { distance, difficulty }

/// One "to validate" view over both pole and puzzlet validations —
/// the validator cares about what's left to do, not which table a row
/// lives in. Rows sort needs-action-first (assigned / in progress
/// before submitted / decided); kind chips recover the old split when
/// wanted. List and map, tapping through to the existing detail
/// routes.
class ValidatorRoute extends StatefulWidget {
  final LandgrabApi api;
  const ValidatorRoute({super.key, required this.api});

  @override
  State<ValidatorRoute> createState() => _ValidatorRouteState();
}

class _ValidatorRouteState extends State<ValidatorRoute> {
  static const _prefKey = 'validator_todo';

  MyValidations? _validations;
  String? _error;
  _ValidatorView _view = _ValidatorView.list;
  _Kind _kind = _Kind.all;
  _Sort _sortBy = _Sort.distance;
  // Free-text filter over the assignment rows (list + map), matching the
  // supervisor Content tab's search.
  String _query = '';

  // Cached so the FutureBuilder doesn't reload the asset on every rebuild.
  Future<String>? _criteria;

  // The validator's own location, for the secondary distance sort.
  // Best-effort: null until acquired, and may be stale — the list falls
  // back to alphabetical when it's missing.
  LatLng? _here;
  final _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadPref();
    _load();
    _locate();
  }

  Future<void> _locate() async {
    try {
      final fix = await LocationService.getCurrent(context: context);
      if (!mounted) return;
      setState(() => _here = LatLng(fix.latitude, fix.longitude));
    } catch (_) {
      // No fix (permission/GPS/off) — distance sort simply doesn't apply.
    }
  }

  /// Orders two rows by distance from [_here]: nearer first, located
  /// rows ahead of unlocated ones. Returns 0 (no preference) when we
  /// have no location or can't compare, letting the title tiebreak.
  int _compareDistance(_TodoRow a, _TodoRow b) {
    final here = _here;
    if (here == null) return 0;
    final da = a.position == null
        ? null
        : _distance.as(LengthUnit.Meter, here, a.position!);
    final db = b.position == null
        ? null
        : _distance.as(LengthUnit.Meter, here, b.position!);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  /// Orders two rows by difficulty, hardest first. Rows without a difficulty
  /// (poles — only puzzlets carry one) sort last, mirroring how unlocated
  /// rows fall to the bottom of the distance sort.
  int _compareDifficulty(_TodoRow a, _TodoRow b) {
    final da = a.difficulty;
    final db = b.difficulty;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  }

  String? _distanceLabel(LatLng? pos) {
    final here = _here;
    if (here == null || pos == null) return null;
    final m = _distance.as(LengthUnit.Meter, here, pos);
    return m < 1000 ? '~${m.round()} m' : '~${(m / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _loadPref() async {
    final isMap = await UiPreferences.getMapPreferred(_prefKey);
    final sortName = await UiPreferences.getSort(_prefKey);
    if (!mounted) return;
    setState(() {
      _view = isMap ? _ValidatorView.map : _ValidatorView.list;
      _sortBy = _Sort.values.firstWhere(
        (s) => s.name == sortName,
        orElse: () => _Sort.distance,
      );
    });
  }

  void _setSort(_Sort s) {
    setState(() => _sortBy = s);
    UiPreferences.setSort(_prefKey, s.name);
  }

  void _setView(_ValidatorView v) {
    setState(() => _view = v);
    // Criteria is a transient reference view — don't make it the default
    // the validator lands on next time; only list/map are remembered.
    if (v != _ValidatorView.criteria) {
      UiPreferences.setMapPreferred(_prefKey, v == _ValidatorView.map);
    }
  }

  Future<String> _loadCriteria() async {
    const fallback =
        '# Validation criteria\n\nAsk your supervisor what to look for.';
    try {
      final s =
          (await rootBundle.loadString('assets/validation/criteria.md')).trim();
      return s.isEmpty ? fallback : s;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await widget.api.listMyValidations();
      if (!mounted) return;
      setState(() => _validations = v);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load assignments: $e');
    }
  }

  Future<void> _openPole(PoleValidationModel v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoleValidationInterstitialRoute(
          api: widget.api,
          validation: v,
          assignments: _validations?.poleValidations ?? const [],
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openPuzzlet(PuzzletValidationModel v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PuzzletValidationInterstitialRoute(
          api: widget.api,
          validation: v,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  // Assigned / in-progress work sorts above already-submitted or
  // decided work, so what still needs doing floats to the top.
  static int _actionRank(ValidationStatus s) => switch (s) {
        ValidationStatus.assigned => 0,
        ValidationStatus.inProgress => 0,
        ValidationStatus.submitted => 1,
        ValidationStatus.unfindable => 1,
        ValidationStatus.accepted => 2,
        ValidationStatus.rejected => 2,
      };

  bool _matchesQuery(_TodoRow r) {
    if (_query.isEmpty) return true;
    return r.title.toLowerCase().contains(_query) ||
        r.subtitle.toLowerCase().contains(_query);
  }

  List<_TodoRow> get _rows {
    final v = _validations;
    if (v == null) return const [];
    final rows = <_TodoRow>[
      if (_kind != _Kind.puzzlets)
        for (final pv in v.poleValidations) _TodoRow.pole(pv, _openPole),
      if (_kind != _Kind.poles)
        for (final zv in v.puzzletValidations)
          _TodoRow.puzzlet(zv, _openPuzzlet),
    ]..retainWhere(_matchesQuery);
    rows.sort((a, b) {
      // Needs-action first, always — decided work never jumps the queue.
      final rank = _actionRank(a.status).compareTo(_actionRank(b.status));
      if (rank != 0) return rank;
      // Then the chosen within-group key (difficulty is opt-in), with
      // distance as the tiebreak either way, then alphabetical.
      if (_sortBy == _Sort.difficulty) {
        final byDiff = _compareDifficulty(a, b);
        if (byDiff != 0) return byDiff;
      }
      final byDist = _compareDistance(a, b);
      if (byDist != 0) return byDist;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: LandgrabAppBar(
        title: 'To validate',
        actions: [
          // Sort only applies to the list; needs-action stays the top
          // grouping either way — this picks the within-group order.
          if (_view == _ValidatorView.list)
            PopupMenuButton<_Sort>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: _setSort,
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: _Sort.distance,
                  checked: _sortBy == _Sort.distance,
                  child: const Text('Nearest first'),
                ),
                CheckedPopupMenuItem(
                  value: _Sort.difficulty,
                  checked: _sortBy == _Sort.difficulty,
                  child: const Text('Hardest first'),
                ),
              ],
            ),
          IconButton(
            onPressed: () {
              _load();
              _locate();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _validations == null
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SegmentedButton<_ValidatorView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: _ValidatorView.list,
                  label: Text('List'),
                  icon: Icon(Icons.list)),
              ButtonSegment(
                  value: _ValidatorView.map,
                  label: Text('Map'),
                  icon: Icon(Icons.map)),
              ButtonSegment(
                  value: _ValidatorView.criteria,
                  label: Text('Criteria'),
                  icon: Icon(Icons.fact_check_outlined)),
            ],
            selected: {_view},
            onSelectionChanged: (set) => _setView(set.first),
          ),
        ),
        // Search + kind filter only apply to the assignment views.
        if (_view != _ValidatorView.criteria)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Search assignments',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        if (_view != _ValidatorView.criteria)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ]),
          ),
        Expanded(
          child: switch (_view) {
            _ValidatorView.list => _buildList(),
            _ValidatorView.map => _buildMap(),
            _ValidatorView.criteria => _buildCriteria(),
          },
        ),
      ],
    );
  }

  Widget _buildCriteria() {
    _criteria ??= _loadCriteria();
    return FutureBuilder<String>(
      future: _criteria,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: scrollInsets(context),
          child: MarkdownView(snap.data!),
        );
      },
    );
  }

  Widget _buildList() {
    final rows = _rows;
    if (rows.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
    }
    // On narrow screens shorten "difficulty 3" to "dif3" to buy back room.
    final compact = MediaQuery.sizeOf(context).width < 400;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        final subtitle =
            compact ? row.subtitle.replaceFirst('difficulty ', 'dif') : row.subtitle;
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
            if (row.attachmentCount > 0) ...[
              const SizedBox(width: 4),
              AttachmentsBadge(count: row.attachmentCount),
            ],
          ]),
          subtitle: Row(children: [
            StatusBadge(
              label: validationStatusLabel(row.status),
              color: statusColorFor(row.status.name),
              dense: true,
            ),
            const SizedBox(width: 6),
            Expanded(
                child: Text(subtitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_distanceLabel(row.position) != null)
                Text(_distanceLabel(row.position)!,
                    style: Theme.of(context).textTheme.bodySmall),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: row.open,
        );
      },
    );
  }

  Widget _buildMap() {
    final rows = _rows;
    final located = rows.where((r) => r.position != null).toList();
    final orphanCount = rows.length - located.length;

    if (located.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            rows.isEmpty
                ? 'Nothing assigned to you yet.'
                : 'None of your assignments have a location yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final pins = located
        .map((r) => r.isPole
            ? MapPin.pole(
                position: r.position!,
                label: r.title,
                color: statusColorFor(r.status.name),
                onTap: r.open,
                accuracyM: r.accuracyM,
              )
            : MapPin.puzzlet(
                position: r.position!,
                label: r.title,
                color: statusColorFor(r.status.name),
                onTap: r.open,
                regionId: r.regionId,
                difficulty: r.difficulty,
              ))
        .toList();

    // Only surface statuses/kinds actually on the map, so the legend
    // stays short and honest.
    final statuses = located.map((r) => r.status).toSet().toList()
      ..sort((a, b) {
        final rank = _actionRank(a).compareTo(_actionRank(b));
        return rank != 0 ? rank : a.name.compareTo(b.name);
      });

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: MapWithBathrooms(
                  api: widget.api,
                  pins: pins,
                  cameraMemoryKey: 'validator_map',
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _MapLegend(
                  statuses: statuses,
                  hasPoles: located.any((r) => r.isPole),
                  hasPuzzlets: located.any((r) => !r.isPole),
                ),
              ),
            ],
          ),
        ),
        if (orphanCount > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$orphanCount without a location — see the list view',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// A pole or puzzlet validation flattened into one to-do row.
class _TodoRow {
  final IconData icon;
  final bool isPole;
  final String title;
  final String subtitle;
  final ValidationStatus status;
  final int attachmentCount;
  final LatLng? position;
  final double? accuracyM;

  /// Puzzlet difficulty (1–10), for the optional difficulty sort. Null for
  /// poles, which carry no validation difficulty.
  final int? difficulty;

  /// The region this row belongs to (puzzlets only). Puzzlets sharing a
  /// region are plotted around the region centroid, since their
  /// individual in-building GPS is unreliable.
  final String? regionId;
  final VoidCallback open;

  _TodoRow._({
    required this.icon,
    required this.isPole,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.attachmentCount,
    required this.position,
    this.accuracyM,
    this.difficulty,
    this.regionId,
    required this.open,
  });

  factory _TodoRow.pole(
      PoleValidationModel v, void Function(PoleValidationModel) open) {
    final pole = v.pole;
    return _TodoRow._(
      icon: Icons.barcode_reader,
      isPole: true,
      title: pole?.label ?? pole?.barcode ?? v.poleId,
      // Type ("pole") is dropped — the icon conveys it.
      subtitle: [
        if (pole != null) pole.barcode,
        '${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
      ].join(' · '),
      status: v.status,
      attachmentCount: pole?.attachmentIds.length ?? 0,
      position: pole == null ? null : LatLng(pole.latitude, pole.longitude),
      accuracyM: pole?.accuracyM,
      open: () => open(v),
    );
  }

  factory _TodoRow.puzzlet(
      PuzzletValidationModel v, void Function(PuzzletValidationModel) open) {
    final puzzlet = v.puzzlet;
    return _TodoRow._(
      icon: Icons.question_mark,
      isPole: false,
      title: puzzlet?.instructions ?? v.puzzletId,
      // Type ("puzzlet") is dropped — the icon conveys it.
      subtitle: [
        if (puzzlet?.region != null) puzzlet!.region!.breadcrumb,
        'difficulty ${puzzlet?.difficulty ?? '?'}',
        '${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
      ].join(' · '),
      status: v.status,
      attachmentCount: puzzlet?.attachmentIds.length ?? 0,
      difficulty: puzzlet?.difficulty,
      position: (puzzlet?.latitude != null && puzzlet?.longitude != null)
          ? LatLng(puzzlet!.latitude!, puzzlet.longitude!)
          : null,
      regionId: puzzlet?.region?.id,
      open: () => open(v),
    );
  }
}

/// Compact key for the validator map: the review-status colours in play,
/// plus the pole/puzzlet icon shapes. Sits over the map's top-left.
class _MapLegend extends StatelessWidget {
  final List<ValidationStatus> statuses;
  final bool hasPoles;
  final bool hasPuzzlets;

  const _MapLegend({
    required this.statuses,
    required this.hasPoles,
    required this.hasPuzzlets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall;
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status',
                style: theme.textTheme.labelSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            for (final s in statuses)
              _row(
                _dot(statusColorFor(s.name)),
                validationStatusLabel(s),
                labelStyle,
              ),
            if (hasPoles || hasPuzzlets) ...[
              const Divider(height: 12),
              if (hasPoles)
                _row(_glyph(Icons.barcode_reader), 'Pole', labelStyle),
              if (hasPuzzlets)
                _row(_glyph(Icons.question_mark), 'Puzzlet', labelStyle),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Widget marker, String label, TextStyle? style) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            marker,
            const SizedBox(width: 6),
            Text(label, style: style),
          ],
        ),
      );

  Widget _dot(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );

  // Mirrors the filled-badge pins so the shapes read the same.
  Widget _glyph(IconData icon) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade400,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(icon, size: 9, color: Colors.white),
      );
}
