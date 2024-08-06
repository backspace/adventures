import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:waydowntown/routes/request_game_route.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  var requestGameRoute = '${dotenv.env['API_ROOT']}/api/v1/games';
  var submitAnswerRoute =
      '${dotenv.env['API_ROOT']}/api/v1/answers?include=game';

  testWidgets('Game is requested, displayed, and answers are posted',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter.onPost(
      requestGameRoute,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": "22261813-2171-453f-a669-db08edc70d6d",
            "type": "games",
            "relationships": {
              "incarnation": {
                "links": {
                  "related":
                      "${dotenv.env['API_ROOT']}/api/v1/incarnations/0091eb84-85c8-4e63-962b-39e1a19d2781"
                },
                "data": {
                  "type": "incarnations",
                  "id": "0091eb84-85c8-4e63-962b-39e1a19d2781"
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
              },
              "relationships": {
                "region": {
                  "links": {
                    "related":
                        "${dotenv.env['API_ROOT']}/api/v1/regions/324fd8f9-cd25-48be-a761-b8680fa72737"
                  },
                  "data": {
                    "type": "regions",
                    "id": "324fd8f9-cd25-48be-a761-b8680fa72737"
                  }
                }
              },
            },
            {
              "id": "324fd8f9-cd25-48be-a761-b8680fa72737",
              "type": "regions",
              "attributes": {"name": "Food Court", "description": null},
              "relationships": {
                "parent": {
                  "links": {
                    "related":
                        "${dotenv.env['API_ROOT']}/api/v1/regions/67cc2c5c-06c2-4e86-9aac-b575fc712862"
                  },
                  "data": {
                    "type": "regions",
                    "id": "67cc2c5c-06c2-4e86-9aac-b575fc712862"
                  }
                }
              }
            },
            {
              "id": "67cc2c5c-06c2-4e86-9aac-b575fc712862",
              "type": "regions",
              "attributes": {"name": "Portage Place", "description": null},
              "relationships": {
                "parent": {
                  "links": {"related": null},
                  "data": null
                }
              }
            }
          ],
          "meta": {}
        },
      ),
    );

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

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
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

  testWidgets('An error is displayed when the game request fails',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter.onPost(
      requestGameRoute,
      (server) => server.reply(500, {}),
    );

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Error fetching game'), findsOneWidget);
  });

  testWidgets('An error is displayed when answering fails but can try again',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter
      ..onPost(
        requestGameRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "22261813-2171-453f-a669-db08edc70d6d",
              "type": "games",
              "relationships": {
                "incarnation": {
                  "links": {
                    "related":
                        "${dotenv.env['API_ROOT']}/api/v1/incarnations/0091eb84-85c8-4e63-962b-39e1a19d2781"
                  },
                  "data": {
                    "type": "incarnations",
                    "id": "0091eb84-85c8-4e63-962b-39e1a19d2781"
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
                },
                "relationships": {
                  "region": {
                    "links": {
                      "related":
                          "${dotenv.env['API_ROOT']}/api/v1/regions/324fd8f9-cd25-48be-a761-b8680fa72737"
                    },
                    "data": {
                      "type": "regions",
                      "id": "324fd8f9-cd25-48be-a761-b8680fa72737"
                    }
                  }
                },
              },
              {
                "id": "324fd8f9-cd25-48be-a761-b8680fa72737",
                "type": "regions",
                "attributes": {"name": "Food Court", "description": null},
                "relationships": {
                  "parent": {
                    "links": {
                      "related":
                          "${dotenv.env['API_ROOT']}/api/v1/regions/67cc2c5c-06c2-4e86-9aac-b575fc712862"
                    },
                    "data": {
                      "type": "regions",
                      "id": "67cc2c5c-06c2-4e86-9aac-b575fc712862"
                    }
                  }
                }
              },
              {
                "id": "67cc2c5c-06c2-4e86-9aac-b575fc712862",
                "type": "regions",
                "attributes": {"name": "Portage Place", "description": null},
                "relationships": {
                  "parent": {
                    "links": {"related": null},
                    "data": null
                  }
                }
              }
            ],
            "meta": {}
          },
        ),
      )
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

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
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
