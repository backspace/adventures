import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:waydowntown/games/bluetooth_collector.dart';
import 'package:waydowntown/games/cardinal_memory.dart';
import 'package:waydowntown/games/code_collector.dart';
import 'package:waydowntown/games/food_court_frenzy.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/games/single_string_input_game.dart';
import 'package:waydowntown/games/string_collector.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/services/user_service.dart';
import 'package:waydowntown/util/get_region_path.dart';
import 'package:waydowntown/widgets/countdown_timer.dart';
import 'package:waydowntown/widgets/game_map.dart';
import 'package:yaml/yaml.dart';

class RunLaunchRoute extends StatefulWidget {
  Run run;
  final Dio dio;
  final PhoenixSocket? testSocket;

  RunLaunchRoute({
    super.key,
    required this.run,
    required this.dio,
    this.testSocket,
  });

  @override
  State<RunLaunchRoute> createState() => _RunLaunchRouteState();
}

class _RunLaunchRouteState extends State<RunLaunchRoute> {
  PhoenixSocket? socket;
  PhoenixChannel? channel;
  bool isReady = false;
  DateTime? startTime;
  Timer? countdownTimer;
  late Future<void> connectionFuture;
  String? _currentUserId;

  List<String> get opponents {
    if (_currentUserId == null) {
      return [];
    }
    return widget.run.participations
        .where((p) => p.userId != _currentUserId)
        .map((p) => p.userId)
        .toList();
  }

  Future<Map<String, dynamic>> _loadGameInfo(BuildContext context) async {
    final yamlString =
        await DefaultAssetBundle.of(context).loadString('assets/concepts.yaml');
    final yamlMap = loadYaml(yamlString);
    final conceptInfo = yamlMap[widget.run.specification.concept];

    if (conceptInfo == null) {
      return {'error': 'Unknown game concept'};
    }

    return {
      'name': conceptInfo['name'],
      'instructions': conceptInfo['instructions'],
      'placeless': conceptInfo['placeless'] ?? false,
    };
  }

  @override
  void initState() {
    super.initState();
    startTime = widget.run.startedAt;
    connectionFuture = _initializeConnection();
  }

  Future<void> _initializeConnection() async {
    _currentUserId = await UserService.getUserId();
    await _connectToSocket();
  }

  Future<void> _connectToSocket() async {
    final apiRoot = dotenv.env['API_ROOT']!.replaceFirst('http', 'ws');

    socket = widget.testSocket ?? PhoenixSocket('$apiRoot/socket/websocket');
    await socket!.connect();

    channel = socket!.addChannel(topic: 'run:${widget.run.id}');
    await channel!.join().future;

    channel!.messages.listen((message) {
      if (message.event == const PhoenixChannelEvent.custom('run_update')) {
        final oldParticipants = widget.run.participations;
        setState(() {
          widget.run = Run.fromJson(message.payload!);

          // Check for new players by comparing old and new participation lists
          final newParticipants = widget.run.participations
              .where((p) =>
                  !oldParticipants.any((old) => old.userId == p.userId) &&
                  p.userId != _currentUserId)
              .toList();

          for (final newPlayer in newParticipants) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Player ${newPlayer.userId} joined the game"),
                duration: const Duration(seconds: 2),
              ),
            );
          }

          if (widget.run.startedAt != null) {
            startTime = widget.run.startedAt!;
            _startCountdown();
          }
        });
      }
    });
  }

  void _startCountdown() {
    if (countdownTimer != null) {
      countdownTimer!.cancel();
    }
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (DateTime.now().isAfter(startTime!)) {
        timer.cancel();
        _navigateToGame();

        // Rerender to hide countdown
        setState(() {});
      }
    });
  }

  void _navigateToGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildGameWidget(widget.run),
      ),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    channel?.leave();
    socket?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: connectionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Error connecting to server: ${snapshot.error}'),
            ),
          );
        }

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
            final isPlaceless = gameInfo?['placeless'] ?? false;

            if (startTime != null && DateTime.now().isBefore(startTime!)) {
              return _buildFullScreenCountdown(context);
            }

            // Otherwise, show the regular game launch screen
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
                    _buildPlayersCard(context),
                    if (widget.run.specification.startDescription != null)
                      _buildInfoCard(
                        context,
                        'Starting point',
                        widget.run.specification.startDescription!,
                      ),
                    Row(
                      children: [
                        if (widget.run.totalAnswers > 1)
                          Expanded(
                            child: _buildInfoCard(
                              context,
                              'Goal',
                              '${widget.run.totalAnswers} answers',
                              key: const Key('total_answers'),
                            ),
                          ),
                        if (widget.run.totalAnswers > 1 &&
                            widget.run.specification.duration != null)
                          const SizedBox(width: 2),
                        if (widget.run.specification.duration != null)
                          if (widget.run.startedAt == null)
                            Expanded(
                                child: _buildInfoCard(
                              context,
                              'Duration',
                              _formatDuration(
                                  widget.run.specification.duration!),
                              key: const Key('duration'),
                            ))
                          else
                            Expanded(
                                child: _buildInfoCard(
                              context,
                              'Time left',
                              CountdownTimer(game: widget.run),
                            ))
                      ],
                    ),
                    if (!isPlaceless)
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(getRegionPath(widget.run.specification)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 100,
                                child: _buildMap(widget.run),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ElevatedButton(
                      onPressed: widget.run.startedAt != null
                          ? () => _navigateToGame()
                          : isReady
                              ? null
                              : _markAsReady,
                      child: Text(widget.run.startedAt != null
                          ? 'Resume Game'
                          : isReady
                              ? 'Waiting for others…'
                              : 'I’m ready'),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
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
            'The game concept "${widget.run.specification.concept}" is not recognized.'),
      ],
    );
  }

  Widget _buildFullScreenCountdown(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).primaryColor,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Game Starting In',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              StartCountdown(startTime: startTime!),
              const SizedBox(height: 40),
              Text(
                'Get Ready!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _markAsReady() async {
    try {
      final userId = await UserService.getUserId();

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final participation = widget.run.participations.firstWhere(
        (p) => p.userId == userId,
        orElse: () => throw Exception('Participation not found'),
      );

      final response = await widget.dio.patch(
        '/waydowntown/participations/${participation.id}',
        data: {
          "data": {
            "type": "participations",
            "id": participation.id,
            "attributes": {"ready": true}
          }
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          isReady = true;
        });
      }
    } catch (e) {
      Sentry.captureException(e);

      _showErrorDialog(context, 'Error marking as ready', e.toString());
    }
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
        return BluetoothCollectorGame(run: game, dio: widget.dio);
      case 'cardinal_memory':
        return CardinalMemoryGame(run: game, dio: widget.dio);
      case 'code_collector':
        return CodeCollectorGame(run: game, dio: widget.dio);
      case 'count_the_items':
      case 'fill_in_the_blank':
        return SingleStringInputGame(run: game, dio: widget.dio);
      case 'food_court_frenzy':
        return FoodCourtFrenzyGame(run: game, dio: widget.dio);
      case 'orientation_memory':
        return OrientationMemoryGame(run: game, dio: widget.dio);
      case 'string_collector':
        return StringCollectorGame(run: game, dio: widget.dio);
      default:
        throw Exception('Unknown game type: ${game.specification.concept}');
    }
  }

  Widget _buildInfoCard(BuildContext context, String title, dynamic content,
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
            if (content is String)
              Text(content)
            else if (content is Widget)
              content
            else
              const Text('Invalid content type'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersCard(BuildContext context) {
    return Card(
      key: const Key('players_card'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Players',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              opponents.isEmpty ? 'Solo' : opponents.join(', '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class StartCountdown extends StatefulWidget {
  final DateTime startTime;

  const StartCountdown({super.key, required this.startTime});

  @override
  State<StartCountdown> createState() => _StartCountdownState();
}

class _StartCountdownState extends State<StartCountdown> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Force rebuild of just this widget
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.startTime.difference(DateTime.now());

    if (remaining.isNegative) {
      return const Text('Starting…',
          style: TextStyle(color: Colors.white, fontSize: 24));
    }

    return Text(
      '${remaining.inSeconds}',
      style: const TextStyle(
          color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
    );
  }
}
