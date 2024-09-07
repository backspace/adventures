import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/string_collector.dart';
import 'package:waydowntown/models/game.dart';

import '../test_helpers.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/answers';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Game game;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockGame(
        concept: 'string_collector', description: 'Collect strings');
  });

  testWidgets('StringCollectorGame displays and submits strings',
      (WidgetTester tester) async {
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'correct1',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 3));
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'incorrect',
            correct: false,
            correctAnswers: 1,
            totalAnswers: 3));
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'correct2',
            correct: true,
            correctAnswers: 2,
            totalAnswers: 3));
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'correct3',
            correct: true,
            correctAnswers: 3,
            totalAnswers: 3,
            isComplete: true));

    await tester.pumpWidget(
        MaterialApp(home: StringCollectorGame(game: game, dio: dio)));
    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('Collect strings'), findsOneWidget);
    expect(find.text('Progress: 0/3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct1');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct1'), findsOneWidget);
    expect(find.text('Progress: 1/3'), findsOneWidget);

    final textField =
        (find.byType(TextField).first.evaluate().first.widget as TextField);
    expect(textField.focusNode?.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('incorrect'), findsOneWidget);
    expect(find.text('Progress: 1/3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct2');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct2'), findsOneWidget);
    expect(find.text('Progress: 2/3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct3');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct3'), findsOneWidget);
    expect(find.text('Progress: 3/3'), findsOneWidget);
    expect(find.text('Congratulations! You have completed the game.'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);

    // Check that the items are in reverse order
    final listItems = find.byType(ListTile);
    expect(tester.widget<ListTile>(listItems.at(0)).title,
        isA<Text>().having((t) => t.data, 'text', 'correct3'));
    expect(tester.widget<ListTile>(listItems.at(1)).title,
        isA<Text>().having((t) => t.data, 'text', 'correct2'));
    expect(tester.widget<ListTile>(listItems.at(2)).title,
        isA<Text>().having((t) => t.data, 'text', 'incorrect'));
    expect(tester.widget<ListTile>(listItems.at(3)).title,
        isA<Text>().having((t) => t.data, 'text', 'correct1'));
  });

  testWidgets('StringCollectorGame handles errors',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      submitAnswerRoute,
      (server) {
        server.reply(500, (request) {
          throw DioException(
            requestOptions: RequestOptions(path: submitAnswerRoute),
            error: 'Server error',
          );
        });
      },
      data: TestHelpers.generateAnswerRequestJson("error_string", game.id),
    );

    await tester.pumpWidget(
        MaterialApp(home: StringCollectorGame(game: game, dio: dio)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'error_string');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('error_string'), findsOneWidget);

    final errorIcon = find.byIcon(Icons.info);
    expect(errorIcon, findsOneWidget);

    await tester.tap(errorIcon);
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text("DioException [unknown]: null\nError: Server error"),
        findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsNothing);
  });
}
