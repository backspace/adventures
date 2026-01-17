import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/single_string_input_game.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  var submitAnswerRoute = '/waydowntown/submissions';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run run;
  late MockPhoenixChannel mockChannel;

  setUp(() async {
    await TestHelpers.setMockUser();
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    run = TestHelpers.createMockRun(concept: 'fill_in_the_blank', answers: [
      const Answer(id: '1', label: 'An enormous headline proclaims ____ quit!')
    ]);

    (_, mockChannel, _) = TestHelpers.setupMockSocket();
  });

  testWidgets('Run is requested, displayed, and answers are posted',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'incorrect',
            correct: false,
            answerId: '1'));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'correct',
            correct: true,
            answerId: '1',
            correctSubmissions: 1,
            totalAnswers: 1,
            isComplete: true));

    await tester.pumpWidget(MaterialApp(
      home: SingleStringInputGame(run: run, dio: dio, channel: mockChannel),
    ));
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isRegistered, isTrue);

    expect(find.text('Parent Region > Test Region'), findsOneWidget);

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
    expect(find.text('Correct answer: correct'), findsOneWidget);
    expect(find.text('Congratulations! You have completed the game.'),
        findsOneWidget);

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('An error is displayed when answering fails but can try again',
      (WidgetTester tester) async {
    TestHelpers.setupMockErrorResponse(dioAdapter, submitAnswerRoute,
        data: TestHelpers.generateSubmissionRequestJson(
            'incorrect', run.id, '1'));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'correct',
            correct: true,
            correctSubmissions: 1,
            totalAnswers: 1,
            isComplete: true,
            answerId: '1'));

    await tester.pumpWidget(MaterialApp(
      home: SingleStringInputGame(run: run, dio: dio, channel: mockChannel),
    ));
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
    expect(find.text('Congratulations! You have completed the game.'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('count_the_items game shows that in the header',
      (WidgetTester tester) async {
    run = TestHelpers.createMockRun(
        concept: 'count_the_items',
        description: 'How many trees can you see in the courtyard?');

    await tester.pumpWidget(MaterialApp(
      home: SingleStringInputGame(run: run, dio: dio, channel: mockChannel),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Count the Items'), findsOneWidget);
  });
}
