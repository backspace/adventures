import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import 'package:mbtiles/mbtiles.dart';

import 'package:path_provider/path_provider.dart';

import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart'
    as vector_tile_renderer;

import 'package:waydowntown/main.dart';

import './map_theme.dart';

final theme = vector_tile_renderer.ThemeReader().read(mapThemeData());

Future<File> copyAssetToFile(String assetFile) async {
  final tempDir = await getTemporaryDirectory();
  final filename = assetFile.split('/').last;
  final file = File('${tempDir.path}/$filename');

  final data = await rootBundle.load(assetFile);
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file;
}

class MapRoute extends StatefulWidget {
  const MapRoute({super.key});

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  final MapController _mapController = MapController();
  double _currentZoom = 15.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: FutureBuilder<MbTilesVectorTileProvider>(
        future: copyAssetToFile('assets/walkway.mbtiles').then((file) {
          return MbTilesVectorTileProvider(
              mbtiles: MbTiles(mbtilesPath: file.path));
        }),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final tileProvider = snapshot.data!;
            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(49.8951, -97.1384),
                    initialZoom: 15.0,
                    minZoom: 13.0,
                    maxZoom: 18.0,
                    onMapEvent: (event) {
                      if (event is MapEventMove) {
                        setState(() {
                          _currentZoom = _mapController.camera.zoom;
                        });
                      }
                    },
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
                    const MarkerLayer(
                      markers: [
                        Marker(
                          width: 80.0,
                          height: 80.0,
                          point: LatLng(49.8951, -97.1384),
                          child: Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.white.withOpacity(0.7),
                    child: Text(
                      'Zoom: ${_currentZoom.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            logger.e(snapshot.error);
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
