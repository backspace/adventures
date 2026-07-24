import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/services/block_territory_service.dart';
import 'package:landgrab/widgets/landgrab_app_bar.dart';
import 'package:landgrab/widgets/landgrab_tile_layer.dart';
import 'package:latlong2/latlong.dart';

/// Supervisor territory-debug map. Draws the pre-computed per-pole zones from
/// `territory.geojson` with EVERY zone filled (not just captured ones, as in
/// gameplay) so their shapes read clearly, each labelled with its pole — so a
/// screenshot of a gap or an odd shape can be lined up against the data by pole
/// name. A diagnostic view for tuning the block/territory pipeline, not a
/// gameplay surface.
class TerritoryMapRoute extends StatefulWidget {
  final LandgrabApi api;
  const TerritoryMapRoute({super.key, required this.api});

  @override
  State<TerritoryMapRoute> createState() => _TerritoryMapRouteState();
}

class _TerritoryMapRouteState extends State<TerritoryMapRoute> {
  static const _fallbackCenter = LatLng(49.8951, -97.1384);

  // Cycled per region so neighbours mostly differ; borders delineate the rest.
  static const _palette = <Color>[
    Color(0xFFEE6677), Color(0xFF4477AA), Color(0xFF228833),
    Color(0xFFCCBB44), Color(0xFF66CCEE), Color(0xFFAA3377),
    Color(0xFFEE7733), Color(0xFF009988), Color(0xFF882255),
    Color(0xFF332288), Color(0xFF999933), Color(0xFF777777),
  ];

  List<TerritoryRegion>? _regions;
  List<DraftPole>? _poles;
  String? _error;
  bool _labels = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        BlockTerritoryService.loadTerritory(),
        widget.api.supervisionListPoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _regions = results[0] as List<TerritoryRegion>?;
        _poles = results[1] as List<DraftPole>?;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  String _poleLabel(String poleId) {
    final pole = _poles?.where((p) => p.id == poleId).firstOrNull;
    return pole?.label ?? pole?.barcode ?? poleId.substring(0, 6);
  }

  // Rough centroid (vertex average) — fine as a label anchor.
  LatLng _centroid(List<LatLng> ring) {
    var lat = 0.0, lng = 0.0;
    for (final p in ring) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / ring.length, lng / ring.length);
  }

  List<LatLng> get _allPoints =>
      [for (final r in _regions ?? const <TerritoryRegion>[]) ...r.ring];

  @override
  Widget build(BuildContext context) {
    final regions = _regions;
    final loading = regions == null || _poles == null;

    return Scaffold(
      appBar: LandgrabAppBar(
        title: 'Territory shapes',
        actions: [
          IconButton(
            tooltip: _labels ? 'Hide labels' : 'Show labels',
            onPressed: loading ? null : () => setState(() => _labels = !_labels),
            icon: Icon(_labels ? Icons.label : Icons.label_off_outlined),
          ),
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
              : regions.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No precomputed territory bundled — build the app '
                          'with assets/experimental/territory.geojson present.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCameraFit: _allPoints.length >= 2
                                ? CameraFit.bounds(
                                    bounds: LatLngBounds.fromPoints(_allPoints),
                                    padding: const EdgeInsets.all(48),
                                  )
                                : null,
                            initialCenter: _allPoints.isEmpty
                                ? _fallbackCenter
                                : _allPoints.first,
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                              flags:
                                  InteractiveFlag.all & ~InteractiveFlag.rotate,
                            ),
                          ),
                          children: [
                            landgrabTileLayer(context),
                            PolygonLayer(
                              polygons: [
                                for (var i = 0; i < regions.length; i++)
                                  Polygon(
                                    points: regions[i].ring,
                                    holePointsList: regions[i].holes.isEmpty
                                        ? null
                                        : regions[i].holes,
                                    color: _palette[i % _palette.length]
                                        .withValues(alpha: 0.4),
                                    borderColor: _palette[i % _palette.length],
                                    borderStrokeWidth: 1.5,
                                    isFilled: true,
                                  ),
                              ],
                            ),
                            // Small dot at each pole's true position, so a pole
                            // sitting outside its own zone is obvious.
                            MarkerLayer(markers: [
                              for (final p in _poles ?? const <DraftPole>[])
                                Marker(
                                  point: LatLng(p.latitude, p.longitude),
                                  width: 10,
                                  height: 10,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.fromBorderSide(
                                          BorderSide(
                                              color: Colors.white, width: 1.5)),
                                    ),
                                  ),
                                ),
                            ]),
                            if (_labels)
                              MarkerLayer(markers: [
                                for (final r in regions)
                                  Marker(
                                    point: _centroid(r.ring),
                                    width: 96,
                                    height: 18,
                                    child: _ZoneLabel(text: _poleLabel(r.poleId)),
                                  ),
                              ]),
                            const _Attribution(),
                          ],
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: Card(
                            color: Theme.of(context)
                                .colorScheme
                                .surface
                                .withValues(alpha: 0.92),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Text(
                                'Every zone filled + labelled by its pole. '
                                'Black dot = the pole itself. '
                                '${regions.length} zones.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  final String text;
  const _ZoneLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 10, color: Colors.black87, fontWeight: FontWeight.w600),
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
