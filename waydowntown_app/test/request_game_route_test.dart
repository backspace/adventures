import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/routes/game_launch_route.dart';
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

  testWidgets('RequestGameRoute hands off to GameLaunchRoute',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      requestGameRoute,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": "22261813-2171-453f-a669-db08edc70d6d",
            "type": "games",
            "attributes": {
              "correct_answers": 2,
              "total_answers": 3,
            },
            "relationships": {
              "incarnation": {
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
              "attributes": {"name": "Test Region", "description": null},
              "relationships": {
                "parent": {"data": null}
              }
            }
          ],
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

    expect(find.byType(GameLaunchRoute), findsOneWidget);
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
