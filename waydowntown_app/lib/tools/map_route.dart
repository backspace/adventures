import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/widgets/game_map.dart';
import 'package:yaml/yaml.dart';

class MapRoute extends StatefulWidget {
  final Dio dio;

  const MapRoute({super.key, required this.dio});

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  List<Specification> specifications = [];
  bool isLoading = true;
  bool isRequestError = false;
  Map<String, String> conceptMarkers = {};

  @override
  void initState() {
    super.initState();
    fetchSpecifications();
    loadConceptMarkers();
  }

  Future<void> fetchSpecifications() async {
    const endpoint = '/waydowntown/specifications';
    try {
      final response = await widget.dio.get(endpoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        final List<dynamic> included = response.data['included'];
        setState(() {
          specifications = data
              .map((json) => Specification.fromJson(json, included))
              .where((specification) => specification.region != null)
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load specifications');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          Sentry.captureException(error);
          isRequestError = true;
          isLoading = false;
        });
      }
      talker.error('Error fetching specifications from $endpoint: $error');
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
    return specifications
        .where((specification) =>
            specification.region != null &&
            specification.region!.latitude != null &&
            specification.region!.longitude != null)
        .map((specification) {
      final region = specification.region!;
      final marker = conceptMarkers[specification.concept] ?? '📍';
      return Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(region.latitude!, region.longitude!),
        child: GestureDetector(
          onTap: () => _onMarkerTap(specification),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Center(
              child: Icon(iconFromName(marker)),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _onMarkerTap(Specification specification) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RequestRunRoute(
          dio: widget.dio,
          specificationId: specification.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isRequestError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: const Center(child: Text('Error fetching specifications')),
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

IconData iconFromName(String name) {
  switch (name) {
    case 'arrow_up_down':
      return LucideIcons.arrow_up_down;
    case 'bluetooth_searching':
      return LucideIcons.bluetooth_searching;
    case 'compass':
      return LucideIcons.compass;
    case 'scan_barcode':
      return LucideIcons.scan_barcode;
    case 'utensils_crossed':
      return LucideIcons.utensils_crossed;
    case 'list_checks':
      return LucideIcons.list_checks;
    case 'phone':
      return LucideIcons.phone;
    case 'rectangle_ellipsis':
      return LucideIcons.rectangle_ellipsis;
    case 'ratio':
      return LucideIcons.ratio;
    case 'tally_5':
      return LucideIcons.tally_5;
    default:
      return LucideIcons.badge_help;
  }
}
