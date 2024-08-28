import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:waydowntown/games/bluetooth_collector.dart';
import 'package:waydowntown/games/code_collector.dart';
import 'package:waydowntown/games/fill_in_the_blank.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/location_header.dart';
import 'package:waydowntown/models/game.dart';
import 'package:yaml/yaml.dart';

class GameLaunchRoute extends StatelessWidget {
  final Game game;
  final Dio dio;

  const GameLaunchRoute({super.key, required this.game, required this.dio});

  Future<Map<String, String?>> _loadGameInfo(BuildContext context) async {
    final yamlString =
        await DefaultAssetBundle.of(context).loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    final conceptInfo = yamlMap[game.incarnation.concept];

    if (conceptInfo == null) {
      return {'error': 'Unknown game concept'};
    }

    return {
      'name': conceptInfo['name'],
      'instructions': conceptInfo['instructions'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String?>>(
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

        return Scaffold(
          appBar: AppBar(title: Text(gameName ?? 'Game Instructions')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocationHeader(game: game),
                const SizedBox(height: 16),
                if (game.incarnation.start != null) ...[
                  Text('Starting point: ${game.incarnation.start}',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
                if (instructions != null) ...[
                  Text('Instructions:',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(instructions),
                  const Spacer(),
                  Center(
                    child: ElevatedButton(
                      child: const Text('Start Game'),
                      onPressed: () {
                        try {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _buildGameWidget(game),
                            ),
                          );
                        } catch (e) {
                          Sentry.captureException(e);
                          _showErrorDialog(
                              context,
                              'Error: Game widget not found',
                              'The widget for game concept "${game.incarnation.concept}" is missing.');
                        }
                      },
                    ),
                  ),
                ] else
                  _buildErrorWidget(context),
              ],
            ),
          ),
        );
      },
    );
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
            'The game concept "${game.incarnation.concept}" is not recognized.'),
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

  Widget _buildGameWidget(Game game) {
    switch (game.incarnation.concept) {
      case 'bluetooth_collector':
        return BluetoothCollectorGame(game: game, dio: dio);
      case 'code_collector':
        return CodeCollectorGame(game: game, dio: dio);
      case 'fill_in_the_blank':
        return FillInTheBlankGame(game: game, dio: dio);
      case 'orientation_memory':
        return OrientationMemoryGame(game: game, dio: dio);
      default:
        throw Exception('Unknown game type: ${game.incarnation.concept}');
    }
  }
}
