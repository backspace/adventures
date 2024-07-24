import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:logging/logging.dart';

final logger = Logger('main');

Future main() async {
  await dotenv.load(fileName: '.env');
  Logger.root.level = kDebugMode ? Level.ALL : Level.INFO;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print(
        '${record.time} [${record.loggerName}] ${record.level.name}: ${record.message}');
  });
  runApp(const Waydowntown());
}

class Waydowntown extends StatelessWidget {
  const Waydowntown({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waydowntown',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'waydowntown'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final dio = Dio(BaseOptions());
    final logger = Logger('dio');

    dio.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
        logPrint: (message) {
          logger.fine(message);
        }));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                child: const Text('Request a game'),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => RequestGameRoute(
                                dio: dio,
                              )));
                }),
          ],
        ),
      ),
    );
  }
}

class RequestGameRoute extends StatefulWidget {
  final Dio dio;

  RequestGameRoute({Key? key, required this.dio}) : super(key: key);

  @override
  _RequestGameRouteState createState() => _RequestGameRouteState();
}

class _RequestGameRouteState extends State<RequestGameRoute> {
  String answer = 'answer';
  Game? game;

  @override
  void initState() {
    super.initState();
    fetchGame();
  }

  Future<void> fetchGame() async {
    final endpoint = '${dotenv.env['API_ROOT']}/api/v1/games';
    try {
      final response = await widget.dio.post(
        endpoint,
        queryParameters: {'include': 'incarnation'},
      );

      if (response.statusCode == 201) {
        setState(() {
          game = Game.fromJson(response.data);
        });
      } else {
        throw Exception('Failed to load game');
      }
    } catch (error) {
      logger.severe('Error fetching game from $endpoint: $error');
    }
  }

  Future<void> submitAnswer(String answer) async {
    try {
      final response = await widget.dio.post(
        '${dotenv.env['API_ROOT']}/api/v1/answers?include=game,game.incarnation',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': answer,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': game!.id},
              },
            },
          },
        },
      );

      setState(() {
        game = Game.fromJson(response.data);
      });
    } catch (error) {
      logger.severe('Error submitting answer: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requested a game?'),
      ),
      body: Center(
        child: Column(
          children: [
            if (game != null)
              Column(
                children: [
                  Text(game!.incarnation.concept),
                  Text(game!.incarnation.mask),
                  Form(
                      child: Column(children: <Widget>[
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Answer',
                      ),
                      onChanged: (value) {
                        answer = value;
                      },
                      onFieldSubmitted: (value) async {
                        answer = value;
                        await submitAnswer(answer);
                      },
                    ),
                    if (game!.isOver)
                      const Text('Done!')
                    else
                      ElevatedButton(
                        onPressed: () async {
                          await submitAnswer(answer);
                        },
                        child: const Text('Submit'),
                      )
                  ]))
                ],
              ),
            if (game == null) const CircularProgressIndicator(),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go back!'),
            ),
          ],
        ),
      ),
    );
  }
}

class Incarnation {
  final String id;
  final String concept;
  final String mask;

  const Incarnation(
      {required this.id, required this.concept, required this.mask});

  factory Incarnation.fromJson(Map<String, dynamic> json) {
    return Incarnation(
      id: json['id'],
      concept: json['attributes']['concept'],
      mask: json['attributes']['mask'],
    );
  }
}

class Game {
  final String id;
  final Incarnation incarnation;
  final bool isOver;

  const Game(
      {required this.id, required this.incarnation, required this.isOver});

  factory Game.fromJson(Map<String, dynamic> json) {
    bool gameIsIncluded = json['data']['type'] != 'games';
    Map<String, dynamic> gameJson = gameIsIncluded
        ? _findIncluded(json['included'], 'games')
        : json['data'];

    return Game(
      id: gameJson['id'],
      incarnation:
          Incarnation.fromJson(_findIncluded(json['included'], 'incarnations')),
      isOver: gameJson['relationships']?['winner_answer']?['links']
                  ?['related'] !=
              null
          ? true
          : false,
    );
  }

  static Map<String, dynamic> _findIncluded(
      List<dynamic> included, String type) {
    for (var item in included) {
      if (item['type'] == type) {
        return item;
      }
    }
    throw Exception('Game not found in included');
  }
}
