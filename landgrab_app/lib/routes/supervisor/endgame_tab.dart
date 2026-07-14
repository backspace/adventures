import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:latlong2/latlong.dart';

/// Map-first editor for the endgame boundary. The centre is picked
/// by panning the map under a fixed crosshair (precise and needs no
/// draggable markers); the initial and final radii render as live
/// circles while their sliders move. Role-holder UI: plain English.
class EndgameTab extends StatefulWidget {
  final LandgrabApi api;
  const EndgameTab({super.key, required this.api});

  @override
  State<EndgameTab> createState() => _EndgameTabState();
}

class _EndgameTabState extends State<EndgameTab> {
  static const _fallbackCenter = LatLng(49.8951, -97.1384);
  static const _initialRadiusRange = (min: 500.0, max: 6000.0);
  static const _finalRadiusRange = (min: 50.0, max: 1000.0);

  final _mapController = MapController();

  bool _loaded = false;
  String? _error;
  bool _saving = false;

  bool _configured = false;
  LatLng _centre = _fallbackCenter;
  double _initialRadius = 2000;
  double _finalRadius = 150;
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _announcedAt;

  // What the server is enforcing right now (as opposed to the form
  // state above, which may hold unsaved edits). Drives the live
  // current-radius readout and circle.
  EndgameZone? _saved;
  Timer? _radiusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _radiusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _saved != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _radiusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final config = await widget.api.getEndgameConfig();
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _announcedAt = config.announcedAt;
        _saved = config.endgame;
        final zone = config.endgame;
        if (zone != null) {
          _configured = true;
          _centre = LatLng(zone.latitude, zone.longitude);
          _initialRadius = zone.initialRadiusM
              .clamp(_initialRadiusRange.min, _initialRadiusRange.max);
          _finalRadius = zone.finalRadiusM
              .clamp(_finalRadiusRange.min, _finalRadiusRange.max);
          _startsAt = zone.startsAt.toLocal();
          _endsAt = zone.endsAt.toLocal();
        }
      });
      if (config.endgame != null) {
        try {
          _mapController.move(_centre, _mapController.camera.zoom);
        } catch (_) {
          // The map hasn't attached yet (this tab builds lazily).
          // Fine: it takes the already-updated _centre as its
          // initialCenter when it does build.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load endgame: $e');
    }
  }

  bool get _valid =>
      _startsAt != null && _endsAt != null && _endsAt!.isAfter(_startsAt!);

  Future<void> _save() async {
    final zone = EndgameZone(
      latitude: _centre.latitude,
      longitude: _centre.longitude,
      startsAt: _startsAt!.toUtc(),
      endsAt: _endsAt!.toUtc(),
      initialRadiusM: _initialRadius,
      finalRadiusM: _finalRadius,
    );
    await _put(zone, 'Endgame saved. Player maps update live.');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the endgame boundary?'),
        content: const Text(
            'Removes the boundary entirely — all poles become capturable again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _put(null, 'Endgame cleared.');
  }

  Future<void> _put(EndgameZone? zone, String successMessage) async {
    setState(() => _saving = true);
    try {
      final config = await widget.api.updateEndgameConfig(zone);
      if (!mounted) return;
      setState(() {
        _configured = config.endgame != null;
        _announcedAt = config.announcedAt;
        _saved = config.endgame;
        if (config.endgame == null) {
          _startsAt = null;
          _endsAt = null;
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDateTime({required bool start}) async {
    final existing = (start ? _startsAt : _endsAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !mounted) return;
    final combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (start) {
        _startsAt = combined;
      } else {
        _endsAt = combined;
      }
    });
  }

  /// Radius the server is enforcing right now, or null when the
  /// saved boundary hasn't begun shrinking (or isn't configured).
  double? _currentRadius() {
    final saved = _saved;
    if (saved == null) return null;
    final now = DateTime.now().toUtc();
    if (!saved.activeAt(now)) return null;
    return saved.radiusAt(now);
  }

  String? _currentRadiusLabel() {
    final radius = _currentRadius();
    if (radius == null) return null;
    final done =
        !DateTime.now().toUtc().isBefore(_saved!.endsAt);
    return done
        ? 'Current radius: ${radius.round()} m (final — shrink complete)'
        : 'Current radius: ${radius.round()} m (shrinking, shown in red)';
  }

  String _format(DateTime? value) {
    if (value == null) return 'not set';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!));
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centre,
                  initialZoom: 13,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (position, _) {
                    final centre = position.center;
                    if (centre != null) {
                      setState(() => _centre = centre);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'ca.chromatin.poles',
                  ),
                  CircleLayer(circles: [
                    CircleMarker(
                      point: _centre,
                      radius: _initialRadius,
                      useRadiusInMeter: true,
                      color: Colors.deepPurple.withValues(alpha: 0.05),
                      borderColor: Colors.deepPurple.withValues(alpha: 0.7),
                      borderStrokeWidth: 2,
                    ),
                    CircleMarker(
                      point: _centre,
                      radius: _finalRadius,
                      useRadiusInMeter: true,
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderColor: Colors.deepPurple,
                      borderStrokeWidth: 2,
                    ),
                    // The boundary players are living with right now
                    // — from the SAVED config, at its saved centre,
                    // so it stays truthful while the form is edited.
                    if (_currentRadius() case final radius?)
                      CircleMarker(
                        point:
                            LatLng(_saved!.latitude, _saved!.longitude),
                        radius: radius,
                        useRadiusInMeter: true,
                        color: Colors.transparent,
                        borderColor: Colors.red.withValues(alpha: 0.8),
                        borderStrokeWidth: 3,
                      ),
                  ]),
                ],
              ),
              // Fixed crosshair: pan the map to aim the centre.
              const IgnorePointer(
                child: Center(
                  child: Icon(Icons.add, size: 36, color: Colors.deepPurple),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentRadiusLabel() case final label?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (_announcedAt != null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'The SYSTEM announcement has already gone out.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: Text(
                      'Initial radius: ${_initialRadius.round()} m'),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _initialRadius,
                    min: _initialRadiusRange.min,
                    max: _initialRadiusRange.max,
                    divisions: 55,
                    onChanged: (v) => setState(() => _initialRadius = v),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: Text('Final radius: ${_finalRadius.round()} m'),
                ),
                Expanded(
                  flex: 2,
                  child: Slider(
                    value: _finalRadius,
                    min: _finalRadiusRange.min,
                    max: _finalRadiusRange.max,
                    divisions: 38,
                    onChanged: (v) => setState(() => _finalRadius = v),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDateTime(start: true),
                    child: Text('Starts: ${_format(_startsAt)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDateTime(start: false),
                    child: Text('Ends: ${_format(_endsAt)}'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (_configured)
                  TextButton(
                    onPressed: _saving ? null : _clear,
                    child: const Text('Clear'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _valid && !_saving ? _save : null,
                  child: Text(_configured ? 'Update' : 'Save'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
