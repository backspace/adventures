import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:waydowntown/main.dart';

class RequestGameRoute extends StatefulWidget {
  final Dio dio;

  const RequestGameRoute({super.key, required this.dio});

  @override
  RequestGameRouteState createState() => RequestGameRouteState();
}

class RequestGameRouteState extends State<RequestGameRoute> {
  String answer = 'answer';
  Game? game;
  bool hasAnsweredIncorrectly = false;
  bool isOver = false;
  bool isRequestError = false;
  bool isAnswerError = false;
  TextEditingController textFieldController = TextEditingController();

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
        queryParameters: {
          'include': 'incarnation,incarnation.region,incarnation.region.parent'
        },
      );

      if (response.statusCode == 201) {
        setState(() {
          game = Game.fromJson(response.data);
        });
      } else {
        throw Exception('Failed to load game');
      }
    } catch (error) {
      setState(() {
        isRequestError = true;
      });
      logger.e('Error fetching game from $endpoint: $error');
    }
  }

  Future<void> submitAnswer(String answer) async {
    try {
      final response = await widget.dio.post(
        '${dotenv.env['API_ROOT']}/api/v1/answers?include=game',
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
        isAnswerError = false;
        isOver = checkWinnerAnswerLink(response.data);
        hasAnsweredIncorrectly = !isOver;
        textFieldController.clear();
      });
    } catch (error) {
      setState(() {
        isAnswerError = true;
      });
      logger.e('Error submitting answer: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: game == null
            ? const Text('Requested a game?')
            : Text(getRegionPath(game!.incarnation)),
      ),
      body: Center(
        child: Column(
          children: [
            if (isRequestError)
              const Text('Error fetching game')
            else if (game != null)
              Column(
                children: [
                  Text(game!.incarnation.concept),
                  Text(game!.incarnation.mask),
                  Form(
                      child: Column(children: <Widget>[
                    TextFormField(
                      controller: textFieldController,
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
                    if (isAnswerError)
                      const Text('Error submitting answer')
                    else if (hasAnsweredIncorrectly)
                      const Text('Wrong'),
                    if (isOver)
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
              )
            else if (game == null)
              const CircularProgressIndicator(),
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
  final Region region;

  const Incarnation(
      {required this.id,
      required this.concept,
      required this.mask,
      required this.region});

  factory Incarnation.fromJson(
      Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    if (relationships == null ||
        relationships['region'] == null ||
        relationships['region']['data'] == null) {
      throw const FormatException('Incarnation must have a region');
    }

    final regionData = relationships['region']['data'];
    final regionJson = included.firstWhere(
      (item) => item['type'] == 'regions' && item['id'] == regionData['id'],
      orElse: () =>
          throw const FormatException('Region not found in included data'),
    );

    return Incarnation(
      id: json['id'],
      concept: attributes['concept'],
      mask: attributes['mask'],
      region: Region.fromJson(regionJson, included),
    );
  }
}

class Region {
  final String id;
  final String name;
  final String? description;
  Region? parentRegion;

  Region(
      {required this.id,
      required this.name,
      this.description,
      this.parentRegion});

  factory Region.fromJson(Map<String, dynamic> json, List<dynamic> included) {
    final attributes = json['attributes'];
    final relationships = json['relationships'];

    Region region = Region(
      id: json['id'],
      name: attributes['name'],
      description: attributes['description'],
    );

    if (relationships != null &&
        relationships['parent'] != null &&
        relationships['parent']['data'] != null) {
      final parentData = relationships['parent']['data'];
      final parentJson = included.firstWhere(
        (item) => item['type'] == 'regions' && item['id'] == parentData['id'],
        orElse: () => null,
      );
      if (parentJson != null) {
        region.parentRegion = Region.fromJson(parentJson, included);
      }
    }

    return region;
  }
}

class Game {
  final String id;
  final Incarnation incarnation;

  Game({required this.id, required this.incarnation});

  factory Game.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final included = json['included'] as List<dynamic>;

    if (data['relationships'] == null ||
        data['relationships']['incarnation'] == null) {
      throw const FormatException('Game must have an incarnation');
    }

    final incarnationData = data['relationships']['incarnation']['data'];
    final incarnationJson = included.firstWhere(
      (item) =>
          item['type'] == 'incarnations' && item['id'] == incarnationData['id'],
      orElse: () =>
          throw const FormatException('Incarnation not found in included data'),
    );

    return Game(
        id: data['id'],
        incarnation: Incarnation.fromJson(incarnationJson, included));
  }
}

bool checkWinnerAnswerLink(Map<String, dynamic> apiResponse) {
  if (apiResponse['included'] == null) return false;

  var included = apiResponse['included'] as List<dynamic>;

  for (var item in included) {
    if (item['type'] == 'games') {
      return item['relationships']?['winner_answer']?['links']?['related'] !=
          null;
    }
  }

  return false;
}

String getRegionPath(Incarnation incarnation) {
  List<String> regionNames = [];
  Region? currentRegion = incarnation.region;

  while (currentRegion != null) {
    regionNames.insert(0, currentRegion.name);
    currentRegion = currentRegion.parentRegion;
  }

  return regionNames.join(" > ");
}
