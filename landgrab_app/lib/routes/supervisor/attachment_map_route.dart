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

  // Retired content is off the game entirely, so it's excluded from this
  // map outright — no pins, no lines, not counted. (Its attachment sheets
  // still list it elsewhere; here we only care about what's in play.)
  List<DraftPole> get _visiblePoles => (_poles ?? const [])
      .where((p) => p.status != DraftStatus.retired)
      .toList();

  List<DraftPuzzlet> get _visiblePuzzlets => (_puzzlets ?? const [])
      .where((p) => p.status != DraftStatus.retired)
      .toList();

  List<LatLng> get _allPoints => [
        for (final p in _visiblePoles) LatLng(p.latitude, p.longitude),
        for (final p in _visiblePuzzlets)
          if (p.latitude != null && p.longitude != null)
            LatLng(p.latitude!, p.longitude!),
      ];

  List<Polyline> _attachmentLines() {
    final polesById = {for (final pole in _visiblePoles) pole.id: pole};
    return [
      for (final puzzlet in _visiblePuzzlets)
        if (puzzlet.poleId != null &&
            puzzlet.latitude != null &&
            puzzlet.longitude != null)
          if (polesById[puzzlet.poleId!] case final pole?)
            Polyline(
              points: [
                LatLng(pole.latitude, pole.longitude),
                LatLng(puzzlet.latitude!, puzzlet.longitude!),
              ],
              strokeWidth: 1.5,
              color: Colors.indigo.shade400.withValues(alpha: 0.4),
            ),
    ];
  }

  List<Marker> _poleMarkers() => [
        for (final pole in _visiblePoles)
          Marker(
            point: LatLng(pole.latitude, pole.longitude),
            width: 32,
            height: 32,
            child: _PolePin(onTap: () => _onPoleTap(pole)),
          ),
      ];

  List<Marker> _puzzletMarkers() => [
        for (final p in _visiblePuzzlets)
          if (p.latitude != null && p.longitude != null)
            Marker(
              point: LatLng(p.latitude!, p.longitude!),
              width: 34,
              height: 34,
              child: _PuzzletPin(
                difficulty: p.difficulty,
                // Transparency IS the attachment cue: attached puzzlets
                // fade so the orphans the supervisor still needs to wire up
                // are the ones that pop.
                faded: p.poleId != null,
                validatorOnly: p.validatorOnly,
                onTap: () => _onPuzzletTap(p),
              ),
            ),
      ];

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
                        ),
                        children: [
                          landgrabTileLayer(context),
                          // Lines under the pins so markers stay on top.
                          PolylineLayer(polylines: _attachmentLines()),
                          MarkerLayer(markers: _poleMarkers()),
                          MarkerLayer(markers: _puzzletMarkers()),
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
            BoxShadow(
                color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.sensors, color: Colors.white, size: 18),
      ),
    );
  }
}

class _PuzzletPin extends StatelessWidget {
  final int difficulty;
  final bool faded;
  final bool validatorOnly;
  final VoidCallback? onTap;

  const _PuzzletPin({
    required this.difficulty,
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
    final circle = Container(
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$difficulty',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
    final pin = validatorOnly
        ? Stack(clipBehavior: Clip.none, children: [
            circle,
            const Positioned(
              right: -2,
              top: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
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
      child: faded ? Opacity(opacity: 0.4, child: pin) : pin,
    );
  }
}
