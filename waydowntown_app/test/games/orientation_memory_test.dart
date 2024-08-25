import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

import 'orientation_memory_test.mocks.dart';

@GenerateMocks([MotionSensors])
void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/answers?include=game';

  late Dio dio;
  late DioAdapter dioAdapter;

  final Game game = Game(
    id: '22261813-2171-453f-a669-db08edc70d6d',
    incarnation: Incarnation(
      id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
      placed: false,
      concept: 'orientation_memory',
      mask: 'not applicable',
      region: Region(
        id: '324fd8f9-cd25-48be-a761-b8680fa72737',
        name: 'Test Region',
        description: null,
      ),
    ),
    correctAnswers: 0,
    totalAnswers: 3,
  );

  late MockMotionSensors mockMotionSensors;

  setUp(() {
    mockMotionSensors = MockMotionSensors();
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
  });

  testWidgets('OrientationMemoryGame displays and submits pattern',
      (WidgetTester tester) async {
    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    // Mock POST response (first submission)
    dioAdapter.onPost(
      submitAnswerRoute,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
            "type": "answers",
            "attributes": {"answer": "up", "correct": true},
            "relationships": {
              "game": {
                "data": {
                  "type": "games",
                  "id": "22261813-2171-453f-a669-db08edc70d6d",
                }
              }
            }
          },
          "included": [
            {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "attributes": {
                "correct_answers": 1,
                "total_answers": 3,
                "complete": false,
              }
            }
          ],
          "meta": {}
        },
      ),
      data: {
        'data': {
          'type': 'answers',
          'attributes': {
            'answer': 'up',
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': '22261813-2171-453f-a669-db08edc70d6d'
              }
            }
          }
        }
      },
    );

    // Mock PATCH response (second submission)
    dioAdapter.onPatch(
      RegExp(r'/waydowntown/answers/.*\?include=game'),
      (server) => server.reply(
        200,
        {
          "data": {
            "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
            "type": "answers",
            "attributes": {"answer": "up|right", "correct": true},
            "relationships": {
              "game": {
                "data": {
                  "type": "games",
                  "id": "22261813-2171-453f-a669-db08edc70d6d",
                }
              }
            }
          },
          "included": [
            {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "attributes": {
                "correct_answers": 2,
                "total_answers": 3,
                "complete": false,
              }
            }
          ],
          "meta": {}
        },
      ),
      data: {
        'data': {
          'type': 'answers',
          'id': '7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4',
          'attributes': {
            'answer': 'up|right',
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': '22261813-2171-453f-a669-db08edc70d6d'
              }
            }
          }
        }
      },
    );

    // Mock PATCH response (third submission - incorrect)
    dioAdapter.onPatch(
      RegExp(r'/waydowntown/answers/.*\?include=game'),
      (server) => server.reply(
        200,
        {
          "data": {
            "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
            "type": "answers",
            "attributes": {"answer": "up|right|left", "correct": false},
            "relationships": {
              "game": {
                "data": {
                  "type": "games",
                  "id": "22261813-2171-453f-a669-db08edc70d6d",
                }
              }
            }
          },
          "included": [
            {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "attributes": {
                "correct_answers": 2,
                "total_answers": 3,
                "complete": false,
              }
            }
          ],
          "meta": {}
        },
      ),
      data: {
        'data': {
          'type': 'answers',
          'id': '7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4',
          'attributes': {
            'answer': 'up|right|left',
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': '22261813-2171-453f-a669-db08edc70d6d'
              }
            }
          }
        }
      },
    );

    // Mock POST response (fourth submission - after incorrect, with new orientation)
    dioAdapter.onPost(
      submitAnswerRoute,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": "8cfe9e24-fe4c-472e-b2eb-3e2c169b11c5",
            "type": "answers",
            "attributes": {"answer": "right", "correct": true},
            "relationships": {
              "game": {
                "data": {
                  "type": "games",
                  "id": "22261813-2171-453f-a669-db08edc70d6d",
                }
              }
            }
          },
          "included": [
            {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "attributes": {
                "correct_answers": 1,
                "total_answers": 3,
                "complete": false,
              }
            }
          ],
          "meta": {}
        },
      ),
      data: {
        'data': {
          'type': 'answers',
          'attributes': {
            'answer': 'right',
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': '22261813-2171-453f-a669-db08edc70d6d'
              }
            }
          }
        }
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        game: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);

    // First submission (POST)
    streamController.add(ScreenOrientationEvent(0));
    await tester.pump();
    expect(find.byKey(const Key('submit-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-up')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '5');
    expect(find.text('Correct! Keep going.'), findsOneWidget);

    // Second submission (PATCH)
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data,
        '5 #');
    expect(find.text('Correct! Keep going.'), findsOneWidget);

    // Third submission (PATCH - incorrect)
    streamController.add(ScreenOrientationEvent(90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-left')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-left')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect. Start over.'), findsOneWidget);

    // Fourth submission (POST - after incorrect, with new orientation)
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '#');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
  });

  testWidgets('OrientationMemoryGame can be won', (WidgetTester tester) async {
    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    dioAdapter.onPost(
      submitAnswerRoute,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
            "type": "answers",
            "attributes": {"answer": "up", "correct": true},
            "relationships": {
              "game": {
                "data": {
                  "type": "games",
                  "id": "22261813-2171-453f-a669-db08edc70d6d",
                }
              }
            }
          },
          "included": [
            {},
            {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "attributes": {
                "correct_answers": 1,
                "total_answers": 1,
                "complete": true,
              }
            }
          ],
          "meta": {}
        },
      ),
      data: {
        'data': {
          'type': 'answers',
          'attributes': {
            'answer': 'up',
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': '22261813-2171-453f-a669-db08edc70d6d'
              }
            }
          }
        }
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        game: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);

    streamController.add(ScreenOrientationEvent(0));
    await tester.pump();
    expect(find.byKey(const Key('submit-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-up')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '5');
    expect(find.text('Congratulations!'), findsOneWidget);

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
        false);
  });
}
