import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/widgets/game_map.dart';
import 'package:yaml/yaml.dart';

class MapRoute extends StatefulWidget {
  final Dio dio;

  const MapRoute({super.key, required this.dio});

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  List<Incarnation> incarnations = [];
  bool isLoading = true;
  bool isRequestError = false;
  Map<String, String> conceptMarkers = {};

  @override
  void initState() {
    super.initState();
    fetchIncarnations();
    loadConceptMarkers();
  }

  Future<void> fetchIncarnations() async {
    const endpoint = '/waydowntown/incarnations';
    try {
      final response = await widget.dio.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        final List<dynamic> included = response.data['included'];
        setState(() {
          incarnations = data
              .map((json) => Incarnation.fromJson(json, included))
              .where((incarnation) => incarnation.region != null)
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load incarnations');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          Sentry.captureException(error);
          isRequestError = true;
          isLoading = false;
        });
      }
      logger.e('Error fetching incarnations from $endpoint: $error');
    }
  }

  Future<void> loadConceptMarkers() async {
    final yamlString = await rootBundle.loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString) as YamlMap;

    conceptMarkers = Map.fromEntries(yamlMap.entries.map((entry) {
      final conceptName = entry.key as String;
      final conceptData = entry.value as YamlMap;
      return MapEntry(conceptName, conceptData['marker'] as String);
    }));
  }

  List<Marker> _buildMarkers() {
    return incarnations
        .where((incarnation) =>
            incarnation.region != null &&
            incarnation.region!.latitude != null &&
            incarnation.region!.longitude != null)
        .map((incarnation) {
      final region = incarnation.region!;
      final marker = conceptMarkers[incarnation.concept] ?? '📍';
      return Marker(
        width: 20.0,
        height: 20.0,
        point: LatLng(region.latitude!, region.longitude!),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Center(
            child: Text(
              marker,
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isRequestError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(child: Text('Error fetching incarnations')),
      );
    } else if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(child: CircularProgressIndicator()),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Map'),
        ),
        body: Stack(
          children: [
            GameMap(
              centre: const LatLng(49.891725, -97.143130),
              markers: _buildMarkers(),
            ),
          ],
        ),
      );
    }
  }
}
