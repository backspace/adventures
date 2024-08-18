import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/routes/bluetooth_collector_game.dart';
import 'package:waydowntown/routes/fill_in_the_blank_game.dart';
import 'package:waydowntown/routes/request_game_route.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;

  setUp(() {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
  });

  const requestGameRoute = '/waydowntown/games';

  testWidgets('RequestGameRoute delegates to BluetoothCollectorGame',
      (WidgetTester tester) async {
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
                            "${dotenv.env['API_ROOT']}/waydowntown/incarnations/0091eb84-85c8-4e63-962b-39e1a19d2781"
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
                      "concept": "bluetooth_collector",
                      "mask": "not applicable"
                    },
                    "relationships": {
                      "region": {
                        "links": {
                          "related":
                              "${dotenv.env['API_ROOT']}/waydowntown/regions/324fd8f9-cd25-48be-a761-b8680fa72737"
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
                    "attributes": {
                      "name": "Place",
                      "description": "it has one"
                    },
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
        data: {
          'data': {
            'type': 'games',
            'attributes': {},
          },
        });

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.byType(BluetoothCollectorGame), findsOneWidget);
  });

  testWidgets('RequestGameRoute delegates to FillInTheBlankGame',
      (WidgetTester tester) async {
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
                      "${dotenv.env['API_ROOT']}/waydowntown/incarnations/0091eb84-85c8-4e63-962b-39e1a19d2781"
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
                        "${dotenv.env['API_ROOT']}/waydowntown/regions/324fd8f9-cd25-48be-a761-b8680fa72737"
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
                        "${dotenv.env['API_ROOT']}/waydowntown/regions/67cc2c5c-06c2-4e86-9aac-b575fc712862"
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
      data: {
        'data': {
          'type': 'games',
          'attributes': {},
        },
      },
    );

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.byType(FillInTheBlankGame), findsOneWidget);
  });

  testWidgets('An error is displayed when the game request fails',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      requestGameRoute,
      (server) => server.reply(500, {}),
    );

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Error fetching game'), findsOneWidget);
  });
}
