import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/routes/validator/pole_validation_detail_route.dart';
import 'package:poles/routes/validator/puzzlet_validation_detail_route.dart';
import 'package:poles/services/ui_preferences.dart';
import 'package:poles/widgets/attachments_badge.dart';
import 'package:poles/widgets/map_pin.dart';
import 'package:poles/widgets/pin_map.dart';
import 'package:poles/widgets/status_badge.dart';

enum _ListOrMap { list, map }

class ValidatorRoute extends StatefulWidget {
  final PolesApi api;
  const ValidatorRoute({super.key, required this.api});

  @override
  State<ValidatorRoute> createState() => _ValidatorRouteState();
}

class _ValidatorRouteState extends State<ValidatorRoute> {
  MyValidations? _validations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My validations'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Puzzlets'),
            Tab(text: 'Poles'),
          ]),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _error != null
            ? Center(child: Text(_error!))
            : _validations == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    _PuzzletValidations(
                      api: widget.api,
                      items: _validations!.puzzletValidations,
                      onChanged: _load,
                    ),
                    _PoleValidations(
                      api: widget.api,
                      items: _validations!.poleValidations,
                      onChanged: _load,
                    ),
                  ]),
      ),
    );
  }
}

// ─── Pole validations: list + map ──────────────────────────────────────

class _PoleValidations extends StatefulWidget {
  final PolesApi api;
  final List<PoleValidationModel> items;
  final Future<void> Function() onChanged;

  const _PoleValidations({
    required this.api,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_PoleValidations> createState() => _PoleValidationsState();
}

class _PoleValidationsState extends State<_PoleValidations> {
  static const _prefKey = 'validator_poles';
  _ListOrMap _view = _ListOrMap.list;

  @override
  void initState() {
    super.initState();
    _loadPref();
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

  Future<void> _open(PoleValidationModel v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoleValidationDetailRoute(api: widget.api, validation: v),
      ),
    );
    if (changed == true) await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
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
        Expanded(
          child: _view == _ListOrMap.list ? _buildList() : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final v = widget.items[i];
        return ListTile(
          title: Row(
            children: [
              Expanded(child: Text(v.pole?.label ?? v.pole?.barcode ?? v.poleId)),
              StatusBadge(
                label: validationStatusLabel(v.status),
                color: statusColorFor(v.status.name),
              ),
              if ((v.pole?.attachmentIds.length ?? 0) > 0) ...[
                const SizedBox(width: 4),
                AttachmentsBadge(count: v.pole!.attachmentIds.length),
              ],
            ],
          ),
          subtitle: Text(
            '${v.pole?.barcode ?? ''} · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(v),
        );
      },
    );
  }

  Widget _buildMap() {
    final located = widget.items.where((v) => v.pole != null).toList();
    if (located.isEmpty) {
      return const Center(child: Text('No assigned poles have a location.'));
    }
    final pins = located
        .map((v) => MapPin(
              position: LatLng(v.pole!.latitude, v.pole!.longitude),
              label: v.pole!.label ?? v.pole!.barcode,
              icon: Icons.location_on,
              color: statusColorFor(v.status.name),
              onTap: () => _open(v),
            ))
        .toList();
    return PinMap(pins: pins);
  }
}

// ─── Puzzlet validations: list + map ──────────────────────────────────

class _PuzzletValidations extends StatefulWidget {
  final PolesApi api;
  final List<PuzzletValidationModel> items;
  final Future<void> Function() onChanged;

  const _PuzzletValidations({
    required this.api,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_PuzzletValidations> createState() => _PuzzletValidationsState();
}

class _PuzzletValidationsState extends State<_PuzzletValidations> {
  static const _prefKey = 'validator_puzzlets';
  _ListOrMap _view = _ListOrMap.list;

  @override
  void initState() {
    super.initState();
    _loadPref();
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

  Future<void> _open(PuzzletValidationModel v) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PuzzletValidationDetailRoute(api: widget.api, validation: v),
      ),
    );
    if (changed == true) await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Center(child: Text('Nothing assigned to you yet.'));
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
        Expanded(
          child: _view == _ListOrMap.list ? _buildList() : _buildMap(),
        ),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      itemCount: widget.items.length,
      itemBuilder: (_, i) {
        final v = widget.items[i];
        return ListTile(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  v.puzzlet?.instructions ?? v.puzzletId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: validationStatusLabel(v.status),
                color: statusColorFor(v.status.name),
              ),
              if ((v.puzzlet?.attachmentIds.length ?? 0) > 0) ...[
                const SizedBox(width: 4),
                AttachmentsBadge(count: v.puzzlet!.attachmentIds.length),
              ],
            ],
          ),
          subtitle: Text(
            'Difficulty ${v.puzzlet?.difficulty ?? '?'} · ${v.comments.length} comment${v.comments.length == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(v),
        );
      },
    );
  }

  Widget _buildMap() {
    final located = widget.items
        .where((v) => v.puzzlet?.latitude != null && v.puzzlet?.longitude != null)
        .toList();
    final orphanCount = widget.items.length - located.length;

    if (located.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            orphanCount > 0
                ? 'None of your assigned puzzlets have a location yet.'
                : 'No assigned puzzlets.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final pins = located
        .map((v) => MapPin(
              position: LatLng(v.puzzlet!.latitude!, v.puzzlet!.longitude!),
              label: v.puzzlet!.instructions,
              icon: Icons.edit_note,
              color: statusColorFor(v.status.name),
              onTap: () => _open(v),
            ))
        .toList();

    return Column(
      children: [
        Expanded(child: PinMap(pins: pins)),
        if (orphanCount > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$orphanCount puzzlet${orphanCount == 1 ? '' : 's'} without a location — see the list view',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
