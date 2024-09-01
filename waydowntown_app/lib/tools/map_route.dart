import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/widgets/game_map.dart';

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

  @override
  void initState() {
    super.initState();
    fetchIncarnations();
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

  List<Marker> _buildMarkers() {
    return incarnations
        .where((incarnation) =>
            incarnation.region != null &&
            incarnation.region!.latitude != null &&
            incarnation.region!.longitude != null)
        .map((incarnation) {
      final region = incarnation.region!;
      return Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng(region.latitude!, region.longitude!),
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40.0,
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
              centre: LatLng(49.891725, -97.143130),
              markers: _buildMarkers(),
            ),
          ],
        ),
      );
    }
  }
}
