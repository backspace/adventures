import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/routes/author/edit_pole_route.dart';
import 'package:landgrab/routes/author/edit_puzzlet_route.dart';
import 'package:landgrab/services/location_service.dart';
import 'package:landgrab/widgets/live_location_layer.dart';
import 'package:latlong2/latlong.dart';

/// Full-screen author scouting map.
///
/// Shows existing puzzlets (as coloured numeric badges — the badge IS
/// the pin, with the difficulty number visible directly) and existing
/// poles nearby. Overlapping pins are spiderfied on tap. The whole
/// point is that the author can walk toward clusters of puzzlets and
/// decide, in place, where to plant a new pole or which puzzlets to
/// assign to a pole they've already staked.
class AuthoringMapRoute extends StatefulWidget {
  final LandgrabApi api;
  const AuthoringMapRoute({super.key, required this.api});

  @override
  State<AuthoringMapRoute> createState() => _AuthoringMapRouteState();
}

class _AuthoringMapRouteState extends State<AuthoringMapRoute> {
  final MapController _controller = MapController();
  LatLng? _userLocation;
  MyDrafts? _drafts;
  bool _loading = true;
  String? _error;
  bool _locating = false;
  // Current camera zoom. Poles resize with this so at low zoom they
  // shrink to un-clickable dots — enough to see them as landmarks
  // without dominating the puzzlet cluster below them.
  double _zoom = 15;

  static const _fallbackCenter = LatLng(49.8951, -97.1384);
  // Wider than the capture-pole default: this view is for planning, so
  // the author wants to see the whole neighbourhood, not just the block
  // they're standing on.
  static const _radiusMetres = 1500.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    LatLng centre = _fallbackCenter;
    try {
      final fix = await LocationService.getCurrent();
      centre = LatLng(fix.latitude, fix.longitude);
      if (mounted) setState(() => _userLocation = centre);
    } catch (_) {
      // Falls back to a downtown-Winnipeg centre so authors can still
      // see the map with no fix; a "Locate me" button retries later.
    }
    await _fetch(centre);
    // Kick the camera to the fetch centre so the initial pin bounds
    // fit around it rather than the far corner of a stale viewport.
    try {
      _controller.move(centre, 15);
    } catch (_) {
      // Not laid out yet; the initialCameraFit handles first frame.
    }
  }

  Future<void> _fetch(LatLng centre) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final drafts = await widget.api.getNearbyDrafts(
        latitude: centre.latitude,
        longitude: centre.longitude,
        radiusM: _radiusMetres,
      );
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    // Prefer the last position the live layer streamed — that's
    // fresh already and avoids a redundant Geolocator round-trip.
    // Fall back to a one-shot fetch only when the stream hasn't
    // produced anything yet (e.g. permission just granted).
    final cached = _userLocation;
    if (cached != null) {
      final zoom = max(_controller.camera.zoom, 15.0);
      _controller.move(cached, zoom);
      await _fetch(cached);
      return;
    }
    setState(() => _locating = true);
    try {
      final fix = await LocationService.getCurrent();
      final me = LatLng(fix.latitude, fix.longitude);
      final zoom = max(_controller.camera.zoom, 15.0);
      _controller.move(me, zoom);
      if (!mounted) return;
      setState(() => _userLocation = me);
      await _fetch(me);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _refreshHere() async {
    try {
      final centre = _controller.camera.center;
      await _fetch(centre);
    } catch (_) {
      // Camera not laid out yet — nothing to refresh.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Author map'),
        actions: [
          IconButton(
            tooltip: 'Refresh from this view',
            onPressed: _loading ? null : _refreshHere,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _locating ? null : _locateMe,
        tooltip: 'Locate me',
        child: _locating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _userLocation ?? _fallbackCenter,
              initialZoom: 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (position, _) {
                final z = position.zoom;
                if (z != null && z != _zoom) {
                  setState(() => _zoom = z);
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
              // Poles render *below* the puzzlet cluster so a pole
              // near a cluster gets covered rather than the other way
              // round — the cluster is what the author is scanning
              // for. Poles are also drawn as their own MarkerLayer
              // (outside the cluster) so they don't collapse into
              // spider-tap flowers alongside puzzlets.
              MarkerLayer(markers: _buildPoleMarkers()),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 40,
                  size: const Size(40, 40),
                  // Spiderfy: when the user taps a cluster at max zoom
                  // (or a small cluster we can't zoom into further)
                  // the plugin fans the pins out radially so each is
                  // tappable individually.
                  spiderfyCluster: true,
                  spiderfySpiralDistanceMultiplier: 3,
                  markers: _buildPuzzletMarkers(),
                  builder: (context, markers) => _ClusterBadge(count: markers.length),
                ),
              ),
              // Live user position + walking-direction cone. Emits
              // every fix back through onPosition so `_userLocation`
              // stays fresh for the "Locate me" FAB to centre on.
              LiveLocationLayer(
                onPosition: (p) {
                  if (!mounted) return;
                  setState(() => _userLocation = LatLng(p.latitude, p.longitude));
                },
              ),
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 4, bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xBFFFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        '© CartoDB · © OpenStreetMap',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: _LoadingChip()),
            ),
          if (_error != null)
            Positioned(
              bottom: 96,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Could not load: $_error',
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildPuzzletMarkers() {
    final drafts = _drafts;
    if (drafts == null) return const [];
    return [
      for (final puzzlet in drafts.puzzlets)
        if (puzzlet.latitude != null && puzzlet.longitude != null)
          Marker(
            point: LatLng(puzzlet.latitude!, puzzlet.longitude!),
            width: 36,
            height: 36,
            child: _PuzzletDifficultyPin(
              difficulty: puzzlet.difficulty,
              attached: puzzlet.poleId != null,
              validatorOnly: puzzlet.validatorOnly,
              onTap: () => _showPuzzletSheet(puzzlet),
            ),
          ),
    ];
  }

  /// Pole markers scale from a full 36 px pin at zoom ≥ 16 down to
  /// a 6 px dot at zoom ≤ 13. The dot is still tappable — the whole
  /// marker box is the hit target — but shrinks small enough that a
  /// pole near a cluster of puzzlets doesn't visually compete with
  /// them at scouting-scale.
  static const double _poleFullZoom = 16;
  static const double _poleTinyZoom = 13;
  static const double _poleFullSize = 36;
  static const double _poleTinySize = 6;

  double get _poleSize {
    if (_zoom >= _poleFullZoom) return _poleFullSize;
    if (_zoom <= _poleTinyZoom) return _poleTinySize;
    final t =
        (_zoom - _poleTinyZoom) / (_poleFullZoom - _poleTinyZoom);
    return _poleTinySize + (_poleFullSize - _poleTinySize) * t;
  }

  List<Marker> _buildPoleMarkers() {
    final drafts = _drafts;
    if (drafts == null) return const [];
    final size = _poleSize;
    final showBadge = size >= 24;
    return [
      for (final pole in drafts.poles)
        Marker(
          point: LatLng(pole.latitude, pole.longitude),
          width: size,
          height: size,
          child: _PolePin(
            onTap: () => _showPoleSheet(pole),
            miniature: !showBadge,
          ),
        ),
    ];
  }

  /// Pole sheet is the primary place attachments are managed — it
  /// shows what's currently attached to this pole and offers nearby
  /// unattached puzzlets you can pull in. Rewriting `_drafts` in
  /// place after each attach/detach lets the sheet stay open and the
  /// map opacities refresh live so you can chain several actions.
  void _showPoleSheet(DraftPole p) {
    final drafts = _drafts;
    if (drafts == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PoleSheet(
        pole: p,
        drafts: drafts,
        api: widget.api,
        onChanged: (updated) {
          if (mounted) setState(() => _drafts = updated);
        },
        onEdit: () => _openEditPole(p),
      ),
    );
  }

  /// Push the pole editor; on save (or delete), pull fresh drafts
  /// from the server so the map reflects any location / label /
  /// deletion changes. The sheet closes itself before invoking this
  /// callback, so the editor is the top route when it opens.
  Future<void> _openEditPole(DraftPole pole) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPoleRoute(api: widget.api, pole: pole),
      ),
    );
    if (result == true && mounted) await _refreshHere();
  }

  Future<void> _openEditPuzzlet(DraftPuzzlet puzzlet) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditPuzzletRoute(api: widget.api, puzzlet: puzzlet),
      ),
    );
    if (result == true && mounted) await _refreshHere();
  }

  void _showPuzzletSheet(DraftPuzzlet p) {
    final drafts = _drafts;
    if (drafts == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PuzzletSheet(
        puzzlet: p,
        drafts: drafts,
        api: widget.api,
        onChanged: (updated) {
          if (mounted) setState(() => _drafts = updated);
        },
        onEdit: () => _openEditPuzzlet(p),
      ),
    );
  }
}

/// Coloured circular badge whose content is the difficulty number
/// itself — no icon, per author feedback that they need to read
/// difficulties at a glance. Colour tier matches the drafts-list badge
/// so the affordance reads the same across surfaces.
class _PuzzletDifficultyPin extends StatelessWidget {
  final int difficulty;
  final bool attached;
  final bool validatorOnly;
  final VoidCallback? onTap;
  const _PuzzletDifficultyPin({
    required this.difficulty,
    this.attached = false,
    this.validatorOnly = false,
    this.onTap,
  });

  Color get _color => switch (difficulty) {
        <= 1 => Colors.green.shade700,
        2 => Colors.lime.shade800,
        3 => Colors.orange.shade700,
        _ => Colors.red.shade700,
      };

  @override
  Widget build(BuildContext context) {
    // Attached puzzlets fade back so the author's eye is drawn to
    // still-unattached ones. Same colour and number so the badge is
    // legible for reference; just quieter.
    final circle = Container(
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$difficulty',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
    // Validator-only badge overlaid in the top-right corner. `Stack`
    // + `Positioned` lets the star hang slightly outside the pin's
    // bounding box so it doesn't hide the difficulty number.
    final pin = validatorOnly
        ? Stack(clipBehavior: Clip.none, children: [
            circle,
            const Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(1),
                  child: Icon(Icons.star, size: 14, color: Colors.amber),
                ),
              ),
            ),
          ])
        : circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: attached ? Opacity(opacity: 0.35, child: pin) : pin,
    );
  }
}

/// Pole sheet: shows what's attached to this pole, and offers nearby
/// unattached puzzlets to attach. Keeps `_drafts` in sync via
/// [onChanged] so the author can chain attach/detach actions and see
/// the map opacities update live between taps.
class _PoleSheet extends StatefulWidget {
  final DraftPole pole;
  final MyDrafts drafts;
  final LandgrabApi api;
  final ValueChanged<MyDrafts> onChanged;
  final VoidCallback onEdit;

  const _PoleSheet({
    required this.pole,
    required this.drafts,
    required this.api,
    required this.onChanged,
    required this.onEdit,
  });

  @override
  State<_PoleSheet> createState() => _PoleSheetState();
}

class _PoleSheetState extends State<_PoleSheet> {
  static const double _nearbyRadiusMetres = 500;
  static const int _nearbyCap = 20;

  late MyDrafts _drafts = widget.drafts;
  final Set<String> _busy = {};

  List<DraftPuzzlet> get _attached =>
      _drafts.puzzlets.where((p) => p.poleId == widget.pole.id).toList();

  /// Puzzlets with no pole yet, sorted by distance ascending. Anchor
  /// point is this pole's own position — "nearby" in this context
  /// literally means "close to the pole", which is what the author
  /// wants to see when planning a cluster of 3-4 puzzlets around it.
  List<(DraftPuzzlet, double)> get _nearbyUnattached {
    const distance = Distance();
    final anchor = LatLng(widget.pole.latitude, widget.pole.longitude);
    final entries = <(DraftPuzzlet, double)>[];
    for (final p in _drafts.puzzlets) {
      if (p.poleId != null) continue;
      if (p.latitude == null || p.longitude == null) continue;
      final d = distance.as(
        LengthUnit.Meter,
        anchor,
        LatLng(p.latitude!, p.longitude!),
      );
      if (d <= _nearbyRadiusMetres) entries.add((p, d));
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    return entries;
  }

  Future<void> _attach(DraftPuzzlet p) async {
    await _run(p, () => widget.api.updateDraftPuzzlet(p.id, poleId: widget.pole.id));
  }

  Future<void> _detach(DraftPuzzlet p) async {
    await _run(p, () => widget.api.updateDraftPuzzlet(p.id, clearPole: true));
  }

  Future<void> _run(DraftPuzzlet p, Future<DraftPuzzlet> Function() call) async {
    setState(() => _busy.add(p.id));
    try {
      final updated = await call();
      if (!mounted) return;
      final list = List<DraftPuzzlet>.of(_drafts.puzzlets);
      final index = list.indexWhere((x) => x.id == updated.id);
      if (index >= 0) {
        list[index] = updated;
      } else {
        list.add(updated);
      }
      final newDrafts = MyDrafts(poles: _drafts.poles, puzzlets: list);
      setState(() => _drafts = newDrafts);
      widget.onChanged(newDrafts);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attached = _attached;
    final nearby = _nearbyUnattached;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const _PolePin(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.pole.label ?? widget.pole.barcode,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit pole',
                  icon: const Icon(Icons.edit_outlined),
                  // Close the sheet first so the editor pushes over
                  // the map, not over the sheet. Parent's onEdit
                  // handles the navigation + post-save refetch.
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onEdit();
                  },
                ),
              ]),
              const SizedBox(height: 4),
              Text('Barcode: ${widget.pole.barcode}',
                  style: theme.textTheme.bodySmall),
              if (widget.pole.notes != null && widget.pole.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(widget.pole.notes!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 24),
              Text('Attached puzzlets · ${attached.length}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (attached.isEmpty)
                Text(
                  'None yet. Attach some from the nearby list below.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final p in attached)
                  _PuzzletRow(
                    puzzlet: p,
                    distanceM: null,
                    busy: _busy.contains(p.id),
                    action: 'Detach',
                    onAction: () => _detach(p),
                  ),
              const SizedBox(height: 24),
              Text('Nearby unattached', style: theme.textTheme.titleMedium),
              Text('Within ${_nearbyRadiusMetres.toInt()} m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 8),
              if (nearby.isEmpty)
                Text(
                  'No unattached puzzlets within this radius. Zoom out and refresh, or author more puzzlets.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final (p, d) in nearby.take(_nearbyCap))
                  _PuzzletRow(
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
    );
  }
}

/// Puzzlet sheet: the puzzlet-centric mirror of `_PoleSheet`. Shows
/// the puzzlet's current pole (with Detach) and nearby poles it
/// could attach to. Same [onChanged] contract so the map opacities
/// update live between actions.
class _PuzzletSheet extends StatefulWidget {
  final DraftPuzzlet puzzlet;
  final MyDrafts drafts;
  final LandgrabApi api;
  final ValueChanged<MyDrafts> onChanged;
  final VoidCallback onEdit;

  const _PuzzletSheet({
    required this.puzzlet,
    required this.drafts,
    required this.api,
    required this.onChanged,
    required this.onEdit,
  });

  @override
  State<_PuzzletSheet> createState() => _PuzzletSheetState();
}

class _PuzzletSheetState extends State<_PuzzletSheet> {
  static const double _nearbyRadiusMetres = 500;
  static const int _nearbyCap = 20;

  late MyDrafts _drafts = widget.drafts;
  late DraftPuzzlet _puzzlet = widget.puzzlet;
  bool _busy = false;

  DraftPole? get _attachedPole {
    final poleId = _puzzlet.poleId;
    if (poleId == null) return null;
    for (final pole in _drafts.poles) {
      if (pole.id == poleId) return pole;
    }
    return null;
  }

  /// Nearby poles that AREN'T the currently-attached one, sorted by
  /// distance. Filtering out the current attachment keeps the list
  /// unambiguous — the "detach" affordance lives above the list.
  List<(DraftPole, double)> get _nearbyPoles {
    if (_puzzlet.latitude == null || _puzzlet.longitude == null) return const [];
    const distance = Distance();
    final anchor = LatLng(_puzzlet.latitude!, _puzzlet.longitude!);
    final entries = <(DraftPole, double)>[];
    for (final pole in _drafts.poles) {
      if (pole.id == _puzzlet.poleId) continue;
      final d = distance.as(
        LengthUnit.Meter,
        anchor,
        LatLng(pole.latitude, pole.longitude),
      );
      if (d <= _nearbyRadiusMetres) entries.add((pole, d));
    }
    entries.sort((a, b) => a.$2.compareTo(b.$2));
    return entries;
  }

  Future<void> _attach(DraftPole pole) async {
    await _run(() => widget.api.updateDraftPuzzlet(_puzzlet.id, poleId: pole.id));
  }

  Future<void> _detach() async {
    await _run(() => widget.api.updateDraftPuzzlet(_puzzlet.id, clearPole: true));
  }

  Future<void> _run(Future<DraftPuzzlet> Function() call) async {
    setState(() => _busy = true);
    try {
      final updated = await call();
      if (!mounted) return;
      final list = List<DraftPuzzlet>.of(_drafts.puzzlets);
      final index = list.indexWhere((x) => x.id == updated.id);
      if (index >= 0) list[index] = updated;
      final newDrafts = MyDrafts(poles: _drafts.poles, puzzlets: list);
      setState(() {
        _drafts = newDrafts;
        _puzzlet = updated;
      });
      widget.onChanged(newDrafts);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attached = _attachedPole;
    final nearby = _nearbyPoles;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: _PuzzletDifficultyPin(difficulty: _puzzlet.difficulty),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Puzzlet · difficulty ${_puzzlet.difficulty}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit puzzlet',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onEdit();
                  },
                ),
              ]),
              const SizedBox(height: 12),
              Text(_puzzlet.instructions),
              const SizedBox(height: 8),
              Text('Answer: ${_puzzlet.answer}',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              Text('Attached pole', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_puzzlet.poleId == null)
                Text('Not attached.', style: theme.textTheme.bodyMedium)
              else if (attached != null)
                _PoleRow(
                  pole: attached,
                  distanceM: null,
                  busy: _busy,
                  action: 'Detach',
                  onAction: _detach,
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attached to a pole outside the current view.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _detach,
                      child: const Text('Detach'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Text('Nearby poles', style: theme.textTheme.titleMedium),
              Text('Within ${_nearbyRadiusMetres.toInt()} m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: 8),
              if (nearby.isEmpty)
                Text(
                  _puzzlet.latitude == null
                      ? 'This puzzlet has no location, so nearby poles can\'t be listed.'
                      : 'No other poles within this radius. Zoom out and refresh, or use the pole sheet from the other side.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                for (final (pole, d) in nearby.take(_nearbyCap))
                  _PoleRow(
                    pole: pole,
                    distanceM: d,
                    busy: _busy,
                    action: 'Attach',
                    onAction: () => _attach(pole),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row equivalent of [_PuzzletRow] but for poles inside the puzzlet
/// sheet. Same leading-widget SizedBox trick to avoid the ListTile
/// unbounded-leading assertion.
class _PoleRow extends StatelessWidget {
  final DraftPole pole;
  final double? distanceM;
  final bool busy;
  final String action;
  final VoidCallback onAction;

  const _PoleRow({
    required this.pole,
    required this.distanceM,
    required this.busy,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const SizedBox(width: 36, height: 36, child: _PolePin()),
        title: Text(
          pole.label ?? pole.barcode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: distanceM == null
            ? Text('Barcode: ${pole.barcode}')
            : Text(
                '${distanceM!.round()} m · ${pole.barcode}',
              ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onAction,
                child: Text(action),
              ),
      ),
    );
  }
}

class _PuzzletRow extends StatelessWidget {
  final DraftPuzzlet puzzlet;
  final double? distanceM;
  final bool busy;
  final String action;
  final VoidCallback onAction;

  const _PuzzletRow({
    required this.puzzlet,
    required this.distanceM,
    required this.busy,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        // ListTile's leading slot needs a bounded widget; the pin
        // has no intrinsic size (it grows to fill its parent), so
        // without this SizedBox the pin claims the entire tile width
        // and Flutter asserts.
        leading: SizedBox(
          width: 36,
          height: 36,
          child: _PuzzletDifficultyPin(difficulty: puzzlet.difficulty),
        ),
        title: Text(
          puzzlet.instructions,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: distanceM == null
            ? null
            : Text('${distanceM!.round()} m away'),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onAction,
                child: Text(action),
              ),
      ),
    );
  }
}

class _PolePin extends StatelessWidget {
  final VoidCallback? onTap;
  /// When true the pin draws as a plain dot without the interior
  /// icon and with a thinner border. Used when the parent sizes the
  /// marker very small at low zooms — the icon can't render legibly
  /// there and the border eats too much of the disc.
  final bool miniature;
  const _PolePin({this.onTap, this.miniature = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo.shade700,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: miniature ? 1 : 2,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: miniature
            ? null
            : const Icon(Icons.location_on, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Cluster badge shown when multiple pins collapse together. Distinct
/// visual (dark neutral, rectangular-ish outline) so it doesn't read
/// as a bright "high difficulty" puzzlet pin.
class _ClusterBadge extends StatelessWidget {
  final int count;
  const _ClusterBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading nearby…'),
          ],
        ),
      ),
    );
  }
}

