import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/services/location_service.dart';
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
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                retinaMode: RetinaMode.isHighDensity(context),
                userAgentPackageName: 'ca.chromatin.poles',
              ),
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
                  markers: _buildMarkers(),
                  builder: (context, markers) => _ClusterBadge(count: markers.length),
                ),
              ),
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 20,
                      height: 20,
                      child: const _UserLocationDot(),
                    ),
                  ],
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

  List<Marker> _buildMarkers() {
    final drafts = _drafts;
    if (drafts == null) return const [];
    final markers = <Marker>[
      for (final puzzlet in drafts.puzzlets)
        if (puzzlet.latitude != null && puzzlet.longitude != null)
          Marker(
            point: LatLng(puzzlet.latitude!, puzzlet.longitude!),
            width: 36,
            height: 36,
            child: _PuzzletDifficultyPin(
              difficulty: puzzlet.difficulty,
              onTap: () => _showPuzzletSheet(puzzlet),
            ),
          ),
      for (final pole in drafts.poles)
        Marker(
          point: LatLng(pole.latitude, pole.longitude),
          width: 36,
          height: 36,
          child: _PolePin(onTap: () => _showPoleSheet(pole)),
        ),
    ];
    return markers;
  }

  void _showPuzzletSheet(DraftPuzzlet p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PuzzletDifficultyPin(difficulty: p.difficulty),
                const SizedBox(width: 12),
                Text(
                  'Puzzlet · difficulty ${p.difficulty}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(p.instructions),
            const SizedBox(height: 8),
            Text('Answer: ${p.answer}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              p.poleId == null
                  ? 'Not assigned to a pole yet.'
                  : 'Assigned to a pole.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  void _showPoleSheet(DraftPole p) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _PolePin(),
                const SizedBox(width: 12),
                Text(
                  p.label ?? p.barcode,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Barcode: ${p.barcode}'),
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.notes!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
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
  final VoidCallback? onTap;
  const _PuzzletDifficultyPin({required this.difficulty, this.onTap});

  Color get _color => switch (difficulty) {
        <= 1 => Colors.green.shade700,
        2 => Colors.lime.shade800,
        3 => Colors.orange.shade700,
        _ => Colors.red.shade700,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}

class _PolePin extends StatelessWidget {
  final VoidCallback? onTap;
  const _PolePin({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.indigo.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
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

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
    );
  }
}
