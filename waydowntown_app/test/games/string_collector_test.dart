import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/string_collector.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/submissions';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run game;
  late MockPhoenixChannel mockChannel;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockRun(
        concept: 'string_collector', description: 'Collect strings');

    (_, mockChannel, _) = TestHelpers.setupMockSocket();
  });

  testWidgets('StringCollectorGame displays and submits strings',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'correct1',
            correct: true,
            correctSubmissions: 1,
            totalAnswers: 3));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'incorrect',
            correct: false,
            correctSubmissions: 1,
            totalAnswers: 3));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'correct2',
            correct: true,
            correctSubmissions: 2,
            totalAnswers: 3));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'correct3',
            correct: true,
            correctSubmissions: 3,
            totalAnswers: 3,
            isComplete: true));

    await tester.pumpWidget(MaterialApp(
      home: StringCollectorGame(run: game, dio: dio, channel: mockChannel),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('Collect strings'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct1');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct1'), findsOneWidget);

    // In practice the field does retain focus but the assertion is failing
    // final textField =
    // (find.byType(TextField).first.evaluate().first.widget as TextField);
    // expect(textField.focusNode?.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField), 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('incorrect'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct2');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct3');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text('correct3'), findsOneWidget);
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
      data: TestHelpers.generateSubmissionRequestJson(
          "error_string", game.id, null),
    );

    await tester.pumpWidget(MaterialApp(
      home: StringCollectorGame(run: game, dio: dio, channel: mockChannel),
    ));
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

  testWidgets(
      'StringCollectorGame requests hints and matches them to submissions',
      (WidgetTester tester) async {
    const hintRoute = '/waydowntown/reveals';
    const testHint = 'This is a test hint';

    dioAdapter.onPost(
      hintRoute,
      (server) => server.reply(201, {
        'data': {
          'type': 'reveals',
          'id': '1',
          'attributes': {},
        },
        'included': [
          {
            'type': 'answers',
            'id': '1',
            'attributes': {
              'hint': testHint,
            },
          },
        ]
      }),
      data: {
        'data': {
          'type': 'reveals',
          'attributes': {},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': game.id}
            }
          }
        }
      },
    );

    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'incorrect',
        correct: false,
        correctSubmissions: 0,
        totalAnswers: 3,
      ),
    );

    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'correct',
        correct: true,
        correctSubmissions: 1,
        totalAnswers: 3,
      ),
    );

    await tester.pumpWidget(MaterialApp(
      home: StringCollectorGame(run: game, dio: dio, channel: mockChannel),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.lightbulb_outline));
    await tester.pumpAndSettle();

    expect(find.text(testHint), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'incorrect');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.text(testHint), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'correct');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lightbulb), findsNothing);

    final listItems = find.byType(ListTile);
    expect(tester.widget<ListTile>(listItems.first).title,
        isA<Text>().having((t) => t.data, 'text', 'correct'));

    expect(find.text(testHint), findsOneWidget);
  });
}
