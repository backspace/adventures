import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/models/pole.dart';
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

  // Tiny reference dots for poles and puzzlets so the supervisor can
  // size the initial radius against where content actually is. Purely
  // decorative — a fetch failure just leaves them empty.
  List<LatLng> _poleDots = const [];
  List<LatLng> _puzzletDots = const [];

  // Bedab's stance-gated final-location messages. DB-backed so the
  // location stays editable as the event unfolds; the server sends them
  // once the shrink begins. DRAFT prefills below appear only when the
  // server has no saved body yet — [FINAL LOCATION] is a deliberate
  // placeholder, since the real spot is a spoiler that must not live in
  // this (public) source.
  static const _draftJoined =
      'Friend — the simulation is collapsing, and Sabuk’s ledgers with it. '
      'Bring your team to [FINAL LOCATION]. Stand with me on freed ground '
      'and see what we made of it.';
  static const _draftOthers =
      'The simulation is collapsing. Where it ends, something is beginning — '
      'the teams who freed the ground know the place. Ask them, and come.';

  final _joinedController = TextEditingController();
  final _othersController = TextEditingController();
  DateTime? _messagesSentAt;
  bool _savingMessages = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMessages();
    _loadContentDots();
    _radiusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _saved != null) setState(() {});
    });
  }

  Future<void> _loadContentDots() async {
    try {
      final results = await Future.wait([
        widget.api.listPoles(),
        widget.api.supervisionListPuzzlets(),
      ]);
      final poles = results[0] as List<Pole>;
      final puzzlets = results[1] as List<DraftPuzzlet>;
      if (!mounted) return;
      setState(() {
        // listPoles already returns validated poles only (retired/draft ones
        // never reach here), so the pole dots need no status filter.
        _poleDots =
            poles.map((p) => LatLng(p.latitude, p.longitude)).toList();
        // supervisionListPuzzlets returns every status, so drop retired ones
        // — they're off the game and shouldn't clutter the endgame view.
        _puzzletDots = puzzlets
            .where((p) =>
                p.status != DraftStatus.retired &&
                p.latitude != null &&
                p.longitude != null)
            .map((p) => LatLng(p.latitude!, p.longitude!))
            .toList();
      });
    } catch (_) {
      // Dots are a convenience; skip silently on failure.
    }
  }

  @override
  void dispose() {
    _radiusTimer?.cancel();
    _joinedController.dispose();
    _othersController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await widget.api.getFinalMessages();
      if (!mounted) return;
      setState(() {
        _messagesSentAt = messages.sentAt;
        _joinedController.text = messages.joined ?? _draftJoined;
        _othersController.text = messages.others ?? _draftOthers;
      });
    } catch (_) {
      // The editor still works from the drafts; a save will surface any
      // real connectivity problem.
      _joinedController.text = _draftJoined;
      _othersController.text = _draftOthers;
    }
  }

  Future<void> _saveMessages() async {
    setState(() => _savingMessages = true);
    try {
      final messages = await widget.api.updateFinalMessages(
        joined: _joinedController.text,
        others: _othersController.text,
      );
      if (!mounted) return;
      setState(() => _messagesSentAt = messages.sentAt);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Final messages saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save messages: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingMessages = false);
    }
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
                  // Deliberate gesture only: panning/zooming to look
                  // around must never move the boundary. (This
                  // replaced a centre-of-viewport crosshair that
                  // changed the centre on every drag.)
                  onLongPress: (_, latLng) =>
                      setState(() => _centre = latLng),
                ),
                children: [
                  landgrabTileLayer(context),
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
                  // Tiny content dots on top of the rings so you can
                  // see how much of the poles/puzzlets a radius covers.
                  // Pixel radii (not metres) so they stay dot-sized at
                  // any zoom.
                  CircleLayer(circles: [
                    for (final p in _poleDots)
                      CircleMarker(
                        point: p,
                        radius: 3,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    for (final p in _puzzletDots)
                      CircleMarker(
                        point: p,
                        radius: 2.5,
                        color: Colors.teal.withValues(alpha: 0.7),
                      ),
                  ]),
                  MarkerLayer(markers: [
                    Marker(
                      point: _centre,
                      width: 36,
                      height: 36,
                      // Anchor the pin's tip at the point.
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.place,
                          size: 36, color: Colors.deepPurple),
                    ),
                  ]),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          'Long-press the map to move the centre',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
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
              if (_poleDots.isNotEmpty || _puzzletDots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.circle,
                        size: 10, color: Color(0x8C000000)),
                    const SizedBox(width: 4),
                    Text('Poles', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.circle, size: 10, color: Colors.teal.shade400),
                    const SizedBox(width: 4),
                    Text('Puzzlets',
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),
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
              _finalMessagesEditor(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Bedab's final-location messages, collapsed by default so the
  /// boundary controls keep the room. Both bodies stay editable until
  /// the server sends them (when the shrink begins).
  Widget _finalMessagesEditor(BuildContext context) {
    final sent = _messagesSentAt;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Bedab’s final messages'),
      subtitle: Text(
        sent != null
            ? 'Sent ${_format(sent.toLocal())} — later edits reach no one.'
            : 'Sent from Bedab when the withdrawal begins. Editable until then.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        TextField(
          controller: _joinedController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'To teams who joined the liberation (precise location)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _othersController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'To everyone else (vague nudge)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _savingMessages ? null : _saveMessages,
            child: const Text('Save messages'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
