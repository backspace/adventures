import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    as vector_tile_renderer;

import '../tools/map_theme.dart';

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
    print('Building GameMap widget');
    final theme = vector_tile_renderer.ThemeReader().read(mapThemeData());

    return FutureBuilder<String>(
      future: copyAssetToFile(context, 'assets/walkway.mbtiles'),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        print('FutureBuilder state: ${snapshot.connectionState}');
        if (snapshot.connectionState == ConnectionState.done) {
          print('MBTiles file path: ${snapshot.data}');
          final tileProvider = MbTilesVectorTileProvider(
              mbtiles: MbTiles(mbtilesPath: snapshot.data!));
          return FlutterMap(
            options: MapOptions(
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
                fileCacheMaximumSizeInBytes: 0,
                textCacheMaxSize: 0,
                memoryTileCacheMaxSize: 0,
                memoryTileDataCacheMaxSize: 0,
              ),
              MarkerLayer(markers: markers),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
