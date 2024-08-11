import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/routes/fill_in_the_blank_game.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  var submitAnswerRoute = '/api/v1/answers?include=game';

  Game game = Game(
    id: '22261813-2171-453f-a669-db08edc70d6d',
    incarnation: Incarnation(
      id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
      concept: 'fill_in_the_blank',
      mask: 'An enormous headline proclaims ____ quit!',
      region: Region(
        id: '324fd8f9-cd25-48be-a761-b8680fa72737',
        name: 'Food Court',
        description: null,
        parentRegion: Region(
          id: '67cc2c5c-06c2-4e86-9aac-b575fc712862',
          name: 'Portage Place',
          description: null,
        ),
      ),
    ),
  );

  testWidgets('Game is requested, displayed, and answers are posted',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter
      ..onPost(
        submitAnswerRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
              "type": "answers",
              "attributes": {
                "answer": "incorrect",
              },
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d"
                  }
                }
              }
            },
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'incorrect',
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
      )
      ..onPost(
        submitAnswerRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "afdc23e8-2f50-4ce6-8407-a48f5fe2643c",
              "type": "answers",
              "attributes": {
                "answer": "correct",
              },
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d"
                  }
                }
              }
            },
            "included": [
              {
                "id": "0091eb84-85c8-4e63-962b-39e1a19d2781",
                "type": "incarnations",
                "attributes": {
                  "concept": "fill_in_the_blank",
                  "mask": "An enormous headline proclaims ____ quit!"
                }
              },
              {
                "id": "22261813-2171-453f-a669-db08edc70d6d",
                "type": "games",
                "attributes": {
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
              'answer': 'correct',
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

    await tester.pumpWidget(
        MaterialApp(home: FillInTheBlankGame(game: game, dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Portage Place > Food Court'), findsOneWidget);

    expect(find.text('fill_in_the_blank'), findsOneWidget);
    expect(
        find.text('An enormous headline proclaims ____ quit!'), findsOneWidget);

    final textField = find.byType(TextField);
    final textFieldWidget = tester.widget<TextField>(textField);

    await tester.enterText(textField, 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Wrong'), findsOneWidget);
    expect(textFieldWidget.controller?.text, '');

    await tester.enterText(find.byType(TextField), 'correct');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('Wrong'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('An error is displayed when answering fails but can try again',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter
      ..onPost(submitAnswerRoute, (server) => server.reply(500, {}))
      ..onPost(
        submitAnswerRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "afdc23e8-2f50-4ce6-8407-a48f5fe2643c",
              "type": "answers",
              "attributes": {
                "answer": "correct",
              },
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d"
                  }
                }
              }
            },
            "included": [
              {
                "id": "0091eb84-85c8-4e63-962b-39e1a19d2781",
                "type": "incarnations",
                "attributes": {
                  "concept": "fill_in_the_blank",
                  "mask": "An enormous headline proclaims ____ quit!"
                }
              },
              {
                "id": "22261813-2171-453f-a669-db08edc70d6d",
                "type": "games",
                "attributes": {"complete": true},
              }
            ],
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'correct',
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

    await tester.pumpWidget(
        MaterialApp(home: FillInTheBlankGame(game: game, dio: dio)));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    final textFieldWidget = tester.widget<TextField>(textField);

    await tester.enterText(textField, 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(textFieldWidget.controller?.text, 'incorrect');
    expect(find.text('Error submitting answer'), findsOneWidget);

    await tester.enterText(textField, 'correct');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(textFieldWidget.controller?.text, '');
    expect(find.text('Error submitting answer'), findsNothing);
    expect(find.text('Done!'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
