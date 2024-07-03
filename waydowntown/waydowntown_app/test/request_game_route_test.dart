import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
// import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'package:waydowntown_app/main.dart';

void main() {
  testWidgets('Game is requested and displayed', (WidgetTester tester) async {
    final dio = Dio(BaseOptions());
    // dio.interceptors.add(PrettyDioLogger());
    final dioAdapter = DioAdapter(dio: dio);

    dioAdapter.onPost(
      'http://localhost:3000/api/v1/games',
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
                      "http://localhost:3000/api/v1/incarnations/0091eb84-85c8-4e63-962b-39e1a19d2781"
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

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('fill_in_the_blank'), findsOneWidget);
    expect(
        find.text('An enormous headline proclaims ____ quit!'), findsOneWidget);
  });
}
