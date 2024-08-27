import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/routes/game_launch_route.dart';
import 'package:waydowntown/routes/request_game_route.dart';

import './test_helpers.dart';

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
    final mockGame = TestHelpers.createMockGame(concept: 'bluetooth_collector');

    TestHelpers.setupMockGameResponse(dioAdapter,
        route: requestGameRoute, game: mockGame);

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.byType(GameLaunchRoute), findsOneWidget);
  });

  testWidgets('An error is displayed when the game request fails',
      (WidgetTester tester) async {
    TestHelpers.setupMockErrorResponse(dioAdapter, requestGameRoute, data: {});

    await tester.pumpWidget(MaterialApp(home: RequestGameRoute(dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Error fetching game'), findsOneWidget);
  });
}
