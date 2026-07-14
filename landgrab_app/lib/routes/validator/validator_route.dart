import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/routes/validator/pole_validation_detail_route.dart';
import 'package:landgrab/routes/validator/puzzlet_validation_detail_route.dart';
import 'package:landgrab/services/ui_preferences.dart';
import 'package:landgrab/widgets/attachments_badge.dart';
import 'package:landgrab/widgets/map_pin.dart';
import 'package:landgrab/widgets/map_with_bathrooms.dart';
import 'package:landgrab/widgets/status_badge.dart';

enum _ListOrMap { list, map }

enum _Kind { all, poles, puzzlets }

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
  _ListOrMap _view = _ListOrMap.list;
  _Kind _kind = _Kind.all;

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
    UiPreferences.setMapPreferred(_prefKey, v == _ListOrMap.map);
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
        builder: (_) =>
            PoleValidationDetailRoute(api: widget.api, validation: v),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _openPuzzlet(PuzzletValidationModel v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            PuzzletValidationDetailRoute(api: widget.api, validation: v),
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
        ValidationStatus.accepted => 2,
        ValidationStatus.rejected => 2,
      };

  List<_TodoRow> get _rows {
    final v = _validations;
    if (v == null) return const [];
    final rows = <_TodoRow>[
      if (_kind != _Kind.puzzlets)
        for (final pv in v.poleValidations) _TodoRow.pole(pv, _openPole),
      if (_kind != _Kind.poles)
        for (final zv in v.puzzletValidations)
          _TodoRow.puzzlet(zv, _openPuzzlet),
    ];
    rows.sort((a, b) {
      final rank = _actionRank(a.status).compareTo(_actionRank(b.status));
      if (rank != 0) return rank;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To validate'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
          child: _view == _ListOrMap.list ? _buildList() : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    final rows = _rows;
    if (rows.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
    }
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
            StatusBadge(
              label: validationStatusLabel(row.status),
              color: statusColorFor(row.status.name),
            ),
            if (row.attachmentCount > 0) ...[
              const SizedBox(width: 4),
              AttachmentsBadge(count: row.attachmentCount),
            ],
          ]),
          subtitle:
              Text(row.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
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
              )
            : MapPin.puzzlet(
                position: r.position!,
                label: r.title,
                color: statusColorFor(r.status.name),
                onTap: r.open,
              ))
        .toList();

    return Column(
      children: [
        Expanded(child: MapWithBathrooms(api: widget.api, pins: pins)),
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
  final VoidCallback open;

  _TodoRow._({
    required this.icon,
    required this.isPole,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.attachmentCount,
    required this.position,
    required this.open,
  });

  factory _TodoRow.pole(
      PoleValidationModel v, void Function(PoleValidationModel) open) {
    final pole = v.pole;
    return _TodoRow._(
      icon: Icons.barcode_reader,
      isPole: true,
      title: pole?.label ?? pole?.barcode ?? v.poleId,
      subtitle: 'Pole'
          '${pole != null ? ' · ${pole.barcode}' : ''}'
          ' · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
      status: v.status,
      attachmentCount: pole?.attachmentIds.length ?? 0,
      position: pole == null ? null : LatLng(pole.latitude, pole.longitude),
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
      subtitle: 'Puzzlet'
          '${puzzlet?.region != null ? ' · ${puzzlet!.region!.breadcrumb}' : ''}'
          ' · difficulty ${puzzlet?.difficulty ?? '?'}'
          ' · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
      status: v.status,
      attachmentCount: puzzlet?.attachmentIds.length ?? 0,
      position: (puzzlet?.latitude != null && puzzlet?.longitude != null)
          ? LatLng(puzzlet!.latitude!, puzzlet.longitude!)
          : null,
      open: () => open(v),
    );
  }
}
