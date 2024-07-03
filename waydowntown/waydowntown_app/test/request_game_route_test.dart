import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown_app/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  testWidgets('Game is requested, displayed, and answers are posted',
      (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter.onPost(
      '${dotenv.env['API_ROOT']}/api/v1/games',
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
              }
            }
          ],
          "meta": {}
        },
      ),
    );

    dioAdapter.onPost(
      '${dotenv.env['API_ROOT']}/api/v1/answers',
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
    );

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('fill_in_the_blank'), findsOneWidget);
    expect(
        find.text('An enormous headline proclaims ____ quit!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
  });
}
