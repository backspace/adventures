import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/routes/game_launch_route.dart';

class RequestGameRoute extends StatefulWidget {
  final Dio dio;
  final String? concept;
  final String? incarnationId;

  const RequestGameRoute({
    super.key,
    required this.dio,
    this.concept,
    this.incarnationId,
  });

  @override
  RequestGameRouteState createState() => RequestGameRouteState();
}

class RequestGameRouteState extends State<RequestGameRoute> {
  String answer = 'answer';
  Game? game;
  bool hasAnsweredIncorrectly = false;
  bool isOver = false;
  bool isRequestError = false;
  TextEditingController textFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchGame();
  }

  Future<void> fetchGame() async {
    const endpoint = '/waydowntown/games';
    try {
      final queryParameters = <String, String>{};
      if (widget.concept != null) {
        queryParameters['filter[incarnation.concept]'] = widget.concept!;
      }
      if (widget.incarnationId != null) {
        queryParameters['filter[incarnation.id]'] = widget.incarnationId!;
      }

      final response = await widget.dio.post(
        endpoint,
        data: {
          'data': {
            'type': 'games',
            'attributes': {},
          },
        },
        queryParameters: queryParameters,
      );

      if (response.statusCode == 201) {
        setState(() {
          game = Game.fromJson(response.data);
        });
      } else {
        throw Exception('Failed to load game');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          Sentry.captureException(error);
          isRequestError = true;
        });
      }
      logger.e('Error fetching game from $endpoint: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isRequestError) {
      return Scaffold(
          appBar: AppBar(title: const Text('Game')),
          body: const Center(child: Text('Error fetching game')));
    } else if (game == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Game')),
          body: const Center(child: CircularProgressIndicator()));
    } else {
      return GameLaunchRoute(game: game!, dio: widget.dio);
    }
  }
}
