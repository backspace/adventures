import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/routes/supervisor/attachment_sheets.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:landgrab/widgets/live_location_layer.dart';
import 'package:latlong2/latlong.dart';

/// Supervisor attachment map — the pole↔puzzlet-wiring counterpart to the
/// content tab's validator-coloured map. This is the supervisor mirror of
/// the author's scouting map: every attached puzzlet is joined to its pole
/// by a line, and attached puzzlets fade back so the un-wired ones stand
/// out. Tapping a pole or puzzlet opens the same attach/detach sheets the
/// pin actions use, so the supervisor can finish wiring content that
/// authors left orphaned — even while it's still in review.
class AttachmentMapRoute extends StatefulWidget {
  final LandgrabApi api;
  const AttachmentMapRoute({super.key, required this.api});

  @override
  State<AttachmentMapRoute> createState() => _AttachmentMapRouteState();
}

class _AttachmentMapRouteState extends State<AttachmentMapRoute> {
  static const _fallbackCenter = LatLng(49.8951, -97.1384);

  List<DraftPole>? _poles;
  List<DraftPuzzlet>? _puzzlets;
  String? _error;
  // Whether an attach/detach happened, so the caller can refresh its own
  // lists when this route pops.
  bool _changed = false;

  // Live camera zoom — drives pin sizing (smaller when zoomed out) and the
  // repulsion spacing (pins only need pushing apart where they'd overlap).
  double _zoom = 15;

  // Pins shrink from _pinFull at zoom ≥ _pinFullZoom to _pinTiny at ≤ _pinTinyZoom.
  static const double _pinFull = 34;
  static const double _pinTiny = 12;
  static const double _pinFullZoom = 16;
  static const double _pinTinyZoom = 13;
  static const int _nudgeIterations = 12;

  double get _pinSize {
    if (_zoom >= _pinFullZoom) return _pinFull;
    if (_zoom <= _pinTinyZoom) return _pinTiny;
    final t = (_zoom - _pinTinyZoom) / (_pinFullZoom - _pinTinyZoom);
    return _pinTiny + (_pinFull - _pinTiny) * t;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Refetch both lists. Keeps the existing lists in place until the new
  /// ones arrive so the map stays mounted across a reload — otherwise
  /// FlutterMap would re-init and snap the camera back to its initial fit.
  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.api.supervisionListPoles(),
        widget.api.supervisionListPuzzlets(),
      ]);
      if (!mounted) return;
      setState(() {
        _poles = results[0] as List<DraftPole>;
        _puzzlets = results[1] as List<DraftPuzzlet>;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  // Content that's off the game — retired or withdrawn — is excluded from
  // this map outright: no pins, no lines, not counted. Validator-only
  // puzzlets are set-aside content, not player-facing wiring, so they're
  // hidden here too. (The attachment sheets still get the full, unfiltered
  // lists — `_poles`/`_puzzlets` — so this only affects what's on the map,
  // not what you can attach.)
  static bool _removed(DraftStatus s) =>
      s == DraftStatus.retired || s == DraftStatus.withdrawn;

  List<DraftPole> get _visiblePoles => (_poles ?? const [])
      .where((p) => !_removed(p.status))
      .toList();

  List<DraftPuzzlet> get _visiblePuzzlets => (_puzzlets ?? const [])
      .where((p) => !_removed(p.status) && !p.validatorOnly)
      .toList();

  List<LatLng> get _allPoints => [
        for (final p in _visiblePoles) LatLng(p.latitude, p.longitude),
        for (final p in _visiblePuzzlets)
          if (p.latitude != null && p.longitude != null)
            LatLng(p.latitude!, p.longitude!),
      ];

  // Screen-declutter: nudge overlapping markers apart so each stays tappable,
  // exactly as the author scouting map does. Poles and puzzlets relax together
  // (a puzzlet clustered on its pole gets pushed off it), and the attachment
  // lines are drawn between the *displaced* positions so they stay connected.
  // Keyed 'p:<id>' / 'z:<id>'; only markers with a location take part.
  Map<String, LatLng> _displacedPositions() {
    final keys = <String>[];
    final lats = <double>[];
    final lngs = <double>[];
    for (final pole in _visiblePoles) {
      keys.add('p:${pole.id}');
      lats.add(pole.latitude);
      lngs.add(pole.longitude);
    }
    for (final p in _visiblePuzzlets) {
      if (p.latitude == null || p.longitude == null) continue;
      keys.add('z:${p.id}');
      lats.add(p.latitude!);
      lngs.add(p.longitude!);
    }
    final n = keys.length;
    if (n == 0) return const {};

    // Metric projection anchored on the centroid so distances read as
    // isotropic metres; spacing is the current pin width in metres-per-pixel.
    var sumLat = 0.0, sumLng = 0.0;
    for (var i = 0; i < n; i++) {
      sumLat += lats[i];
      sumLng += lngs[i];
    }
    final cLat = sumLat / n, cLng = sumLng / n;
    const mPerDegLat = 111000.0;
    final mPerDegLng = 111000.0 * cos(cLat * pi / 180);
    final mPerPx = 156543.03392 * cos(cLat * pi / 180) / pow(2, _zoom);
    final minSpacing = _pinSize * mPerPx;

    final xs = List<double>.filled(n, 0);
    final ys = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      xs[i] = (lngs[i] - cLng) * mPerDegLng;
      ys[i] = (lats[i] - cLat) * mPerDegLat;
    }

    for (var iter = 0; iter < _nudgeIterations; iter++) {
      var moved = false;
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          final dx = xs[j] - xs[i];
          final dy = ys[j] - ys[i];
          final d = sqrt(dx * dx + dy * dy);
          if (d >= minSpacing) continue;
          final nx = d < 0.001 ? 1.0 : dx / d;
          final ny = d < 0.001 ? 0.0 : dy / d;
          final push = (minSpacing - d) / 2;
          xs[i] -= nx * push;
          ys[i] -= ny * push;
          xs[j] += nx * push;
          ys[j] += ny * push;
          moved = true;
        }
      }
      if (!moved) break;
    }

    final out = <String, LatLng>{};
    for (var i = 0; i < n; i++) {
      out[keys[i]] =
          LatLng(cLat + ys[i] / mPerDegLat, cLng + xs[i] / mPerDegLng);
    }
    return out;
  }

  List<Polyline> _attachmentLines(Map<String, LatLng> displaced) {
    final polesById = {for (final pole in _visiblePoles) pole.id: pole};
    return [
      for (final puzzlet in _visiblePuzzlets)
        if (puzzlet.poleId != null)
          if (polesById[puzzlet.poleId!] case final pole?)
            if (displaced['p:${pole.id}'] case final poleAt?)
              if (displaced['z:${puzzlet.id}'] case final puzzletAt?)
                Polyline(
                  points: [poleAt, puzzletAt],
                  strokeWidth: 1.5,
                  color: Colors.indigo.shade400.withValues(alpha: 0.4),
                ),
    ];
  }

  // Poles with at least one attached puzzlet that's hidden from this map —
  // retired/withdrawn or validator-only. Computed from the raw (unfiltered)
  // `_puzzlets` so we can flag a pole that looks empty here but actually has
  // off-map content wired to it.
  Set<String> get _polesWithHiddenAttached => {
        for (final p in (_puzzlets ?? const <DraftPuzzlet>[]))
          if (p.poleId != null && (_removed(p.status) || p.validatorOnly))
            p.poleId!,
      };

  List<Marker> _poleMarkers(Map<String, LatLng> displaced) {
    final size = _pinSize;
    final flagged = _polesWithHiddenAttached;
    return [
      for (final pole in _visiblePoles)
        if (displaced['p:${pole.id}'] case final at?)
          Marker(
            point: at,
            width: size,
            height: size,
            child: _PolePin(
              dimension: size,
              flagged: flagged.contains(pole.id),
              onTap: () => _onPoleTap(pole),
            ),
          ),
    ];
  }

  List<Marker> _puzzletMarkers(Map<String, LatLng> displaced) {
    final size = _pinSize;
    return [
      for (final p in _visiblePuzzlets)
        if (displaced['z:${p.id}'] case final at?)
          Marker(
            point: at,
            width: size,
            height: size,
            child: _PuzzletPin(
              dimension: size,
              difficulty: p.difficulty,
              // Transparency IS the attachment cue: attached puzzlets fade so
              // the orphans the supervisor still needs to wire up are the ones
              // that pop.
              faded: p.poleId != null,
              validatorOnly: p.validatorOnly,
              onTap: () => _onPuzzletTap(p),
            ),
          ),
    ];
  }

  Future<void> _onPoleTap(DraftPole pole) async {
    final changed = await showSupervisorPoleAttachments(
      context,
      api: widget.api,
      pole: pole,
      allPuzzlets: _puzzlets ?? const [],
    );
    if (changed && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _onPuzzletTap(DraftPuzzlet puzzlet) async {
    final changed = await showSupervisorPuzzletPole(
      context,
      api: widget.api,
      puzzlet: puzzlet,
      allPoles: _poles ?? const [],
      // Full (unfiltered) list — used only to count each pole's attached
      // puzzlets, so retired/validator-only still count toward a pole's load.
      allPuzzlets: _puzzlets ?? const [],
    );
    if (changed && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _poles == null || _puzzlets == null;
    final orphanNoLocation = _visiblePuzzlets
        .where((p) => p.poleId == null && p.latitude == null)
        .length;
    final displaced = loading ? const <String, LatLng>{} : _displacedPositions();

    return PopScope<bool>(
      // Hand back whether anything changed so the content tab can refresh.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: LandgrabAppBar(
          title: 'Attachments',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _error != null
            ? Center(child: Text(_error!))
            : loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCameraFit: _allPoints.length >= 2
                              ? CameraFit.bounds(
                                  bounds:
                                      LatLngBounds.fromPoints(_allPoints),
                                  padding: const EdgeInsets.all(64),
                                )
                              : null,
                          initialCenter: _allPoints.isEmpty
                              ? _fallbackCenter
                              : _allPoints.first,
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all &
                                ~InteractiveFlag.rotate,
                          ),
                          // Re-declutter + re-size as the zoom changes; the
                          // small epsilon keeps a pinch from rebuilding every
                          // frame.
                          onPositionChanged: (pos, _) {
                            final z = pos.zoom;
                            if (z != null && (z - _zoom).abs() >= 0.05) {
                              setState(() => _zoom = z);
                            }
                          },
                        ),
                        children: [
                          landgrabTileLayer(context),
                          // Lines under the pins so markers stay on top.
                          PolylineLayer(polylines: _attachmentLines(displaced)),
                          MarkerLayer(markers: _poleMarkers(displaced)),
                          MarkerLayer(markers: _puzzletMarkers(displaced)),
                          const LiveLocationLayer(),
                          const _Attribution(),
                        ],
                      ),
                      const Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: _LegendCard(),
                      ),
                      if (orphanNoLocation > 0)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Card(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.95),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                '$orphanNoLocation unattached '
                                'puzzlet${orphanNoLocation == 1 ? '' : 's'} '
                                'without a location — attach '
                                '${orphanNoLocation == 1 ? 'it' : 'them'} from '
                                'a pole (tap a pole → Show all).',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  const _LegendCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.link, size: 16, color: Colors.indigo),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Lines link puzzlets to their pole. Faded = attached. '
                '! = hidden (retired/validator-only) content attached. '
                'Tap a pin to change attachments.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return const Align(
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
    );
  }
}

class _PolePin extends StatelessWidget {
  final double dimension;
  // Marks a pole that has hidden (retired/withdrawn or validator-only)
  // puzzlets attached — content that isn't drawn on this map — with a small
  // amber "!" badge so the supervisor can spot it.
  final bool flagged;
  final VoidCallback? onTap;
  const _PolePin({this.dimension = 34, this.flagged = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Below ~20 px the glyph can't render legibly; drop to a plain dot.
    final showGlyph = dimension >= 20;
    final circle = Container(
      decoration: BoxDecoration(
        color: Colors.indigo.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: showGlyph ? 2 : 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: showGlyph
          ? Icon(Icons.sensors, color: Colors.white, size: dimension * 0.55)
          : null,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: flagged
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                circle,
                Positioned(
                  right: -3,
                  top: -3,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.error,
                        size: 14, color: Colors.amber.shade800),
                  ),
                ),
              ],
            )
          : circle,
    );
  }
}

class _PuzzletPin extends StatelessWidget {
  final double dimension;
  final int difficulty;
  final bool faded;
  final bool validatorOnly;
  final VoidCallback? onTap;

  const _PuzzletPin({
    required this.difficulty,
    this.dimension = 34,
    this.faded = false,
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
    // Below ~18 px the difficulty numeral can't render legibly; drop to a
    // plain coloured dot.
    final showNumber = dimension >= 18;
    final circle = Container(
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: showNumber ? 2 : 1),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: showNumber
          ? Text(
              '$difficulty',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: dimension * 0.44,
              ),
            )
          : null,
    );
    final starSize = (dimension * 0.42).clamp(9.0, 14.0);
    final pin = validatorOnly
        ? Stack(clipBehavior: Clip.none, children: [
            circle,
            Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: Icon(Icons.star, size: starSize, color: Colors.amber),
                ),
              ),
            ),
          ])
        : circle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: faded ? Opacity(opacity: 0.4, child: pin) : pin,
    );
  }
}
