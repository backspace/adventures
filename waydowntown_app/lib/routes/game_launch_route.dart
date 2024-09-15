import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/game_header.dart';
import 'package:waydowntown/games/bluetooth_collector.dart';
import 'package:waydowntown/games/cardinal_memory.dart';
import 'package:waydowntown/games/code_collector.dart';
import 'package:waydowntown/games/food_court_frenzy.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/games/single_string_input_game.dart';
import 'package:waydowntown/games/string_collector.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/game_map.dart';
import 'package:yaml/yaml.dart';

class GameLaunchRoute extends StatefulWidget {
  Run game;
  final Dio dio;

  GameLaunchRoute({super.key, required this.game, required this.dio});

  @override
  State<GameLaunchRoute> createState() => _GameLaunchRouteState();
}

class _GameLaunchRouteState extends State<GameLaunchRoute> {
  Future<Map<String, dynamic>> _loadGameInfo(BuildContext context) async {
    final yamlString =
        await DefaultAssetBundle.of(context).loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    final conceptInfo = yamlMap[widget.game.specification.concept];

    if (conceptInfo == null) {
      return {'error': 'Unknown game concept'};
    }

    return {
      'name': conceptInfo['name'],
      'instructions': conceptInfo['instructions'],
      'placed': conceptInfo['placed'] ?? true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadGameInfo(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final gameInfo = snapshot.data;
        if (gameInfo?['error'] != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: _buildErrorWidget(context),
          );
        }

        final gameName = gameInfo?['name'];
        final instructions = gameInfo?['instructions'];
        final isPlaced = gameInfo?['placed'] ?? true;

        return Scaffold(
          appBar: AppBar(title: Text(gameName ?? 'Game Instructions')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                if (instructions != null)
                  _buildInfoCard(
                    context,
                    'Instructions',
                    instructions,
                  ),
                if (widget.game.specification.start != null)
                  _buildInfoCard(
                    context,
                    'Starting point',
                    widget.game.specification.start!,
                  ),
                Row(
                  children: [
                    if (widget.game.totalAnswers > 1)
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          'Goal',
                          '${widget.game.totalAnswers} answers',
                          key: const Key('total_answers'),
                        ),
                      ),
                    if (widget.game.totalAnswers > 1 &&
                        widget.game.specification.duration != null)
                      const SizedBox(width: 2),
                    if (widget.game.specification.duration != null)
                      Expanded(
                        child: _buildInfoCard(
                          context,
                          'Duration',
                          _formatDuration(widget.game.specification.duration!),
                          key: const Key('duration'),
                        ),
                      ),
                  ],
                ),
                if (isPlaced)
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          GameHeader(game: widget.game),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: _buildMap(widget.game),
                          ),
                        ],
                      ),
                    ),
                  ),
                ElevatedButton(
                  child: Text(widget.game.startedAt != null
                      ? 'Resume Game'
                      : 'Start Game'),
                  onPressed: () async {
                    try {
                      if (widget.game.startedAt == null) {
                        final response = await widget.dio.post(
                          '/waydowntown/games/${widget.game.id}/start',
                          data: {
                            'data': {
                              'type': 'games',
                              'id': widget.game.id,
                            },
                          },
                        );
                        if (response.statusCode == 200) {
                          setState(() {
                            logger.d('Game started: ${response.data}');
                            widget.game = Run.fromJson(response.data);
                          });
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _buildGameWidget(widget.game),
                        ),
                      );
                    } catch (e) {
                      Sentry.captureException(e);
                      _showErrorDialog(
                          context, 'Error starting game', e.toString());
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return '${duration.inSeconds} second${duration.inSeconds > 1 ? 's' : ''}';
    }
  }

  Widget _buildMap(Run game) {
    if (game.specification.region?.latitude != null &&
        game.specification.region?.longitude != null) {
      return GameMap(
        centre: LatLng(game.specification.region!.latitude!,
            game.specification.region!.longitude!),
        markers: [
          Marker(
            point: LatLng(game.specification.region!.latitude!,
                game.specification.region!.longitude!),
            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
          ),
        ],
      );
    } else {
      return const Center(
        child: Text('Map unavailable - location not specified'),
      );
    }
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Error: Unknown game concept',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.red)),
        const SizedBox(height: 8),
        Text(
            'The game concept "${widget.game.specification.concept}" is not recognized.'),
      ],
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameWidget(Run game) {
    switch (game.specification.concept) {
      case 'bluetooth_collector':
        return BluetoothCollectorGame(game: game, dio: widget.dio);
      case 'cardinal_memory':
        return CardinalMemoryGame(game: game, dio: widget.dio);
      case 'code_collector':
        return CodeCollectorGame(game: game, dio: widget.dio);
      case 'count_the_items':
      case 'fill_in_the_blank':
        return SingleStringInputGame(game: game, dio: widget.dio);
      case 'food_court_frenzy':
        return FoodCourtFrenzyGame(game: game, dio: widget.dio);
      case 'orientation_memory':
        return OrientationMemoryGame(game: game, dio: widget.dio);
      case 'string_collector':
        return StringCollectorGame(game: game, dio: widget.dio);
      default:
        throw Exception('Unknown game type: ${game.specification.concept}');
    }
  }

  Widget _buildInfoCard(BuildContext context, String title, String content,
      {Key? key}) {
    return Card(
      key: key,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
}
