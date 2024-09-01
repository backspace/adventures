import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    as vector_tile_renderer;

import '../tools/map_theme.dart';

const north_grain_exchange = 49.89684619087244;
const east_grain_exchange = -97.13601201018146;
const south_convention_centre_parking = 49.88737391678073;
const west_one_canada_centre = -97.15091617244872;

const boundary_padding = 0.001;

Future<String> copyAssetToFile(BuildContext context, String assetPath) async {
  final assetBundle = DefaultAssetBundle.of(context);
  final data = await assetBundle.load('assets/walkway.mbtiles');

  final tempDir = await getTemporaryDirectory();
  final filename = assetPath.split('/').last;
  final file = File('${tempDir.path}/$filename');

  try {
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  } catch (e) {
    print('error writing file: $e');
  }
  return file.path;
}

class GameMap extends StatelessWidget {
  final LatLng centre;
  final List<Marker> markers;

  const GameMap({
    super.key,
    required this.centre,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = vector_tile_renderer.ThemeReader().read(mapThemeData());

    return FutureBuilder<String>(
      future: copyAssetToFile(context, 'assets/walkway.mbtiles'),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final tileProvider = MbTilesVectorTileProvider(
              mbtiles: MbTiles(mbtilesPath: snapshot.data!));
          return FlutterMap(
            options: MapOptions(
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(north_grain_exchange + boundary_padding,
                      east_grain_exchange + boundary_padding),
                  const LatLng(
                      south_convention_centre_parking - boundary_padding,
                      west_one_canada_centre - boundary_padding),
                ),
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              initialCenter: centre,
              initialZoom: 16.0,
              minZoom: 13.0,
              maxZoom: 18.0,
            ),
            children: [
              VectorTileLayer(
                theme: theme,
                tileProviders: TileProviders({
                  'openmaptiles': tileProvider,
                }),
                maximumZoom: 18,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(20, 20),
                  padding: const EdgeInsets.all(50),
                  markers: markers,
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
              CurrentLocationLayer(),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
