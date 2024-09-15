import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';

import 'orientation_memory_test.mocks.dart';

@GenerateMocks([MotionSensors])
void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/submissions';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run game;
  late MockMotionSensors mockMotionSensors;

  setUp(() {
    mockMotionSensors = MockMotionSensors();
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockRun(concept: 'orientation_memory');
  });

  testWidgets('OrientationMemoryGame displays and submits pattern',
      (WidgetTester tester) async {
    final ids1 = TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'up',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 3,
            method: 'POST'));

    final ids2 = TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: '/waydowntown/submissions/${ids1['submissionId']}',
            submission: 'up|right',
            correct: true,
            correctAnswers: 2,
            totalAnswers: 3,
            method: 'PATCH',
            runId: ids1['gameId'],
            submissionId: ids1['submissionId']));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: '/waydowntown/submissions/${ids2['submissionId']}',
            submission: 'up|right|left',
            correct: false,
            method: 'PATCH',
            runId: ids1['gameId'],
            submissionId: ids2['submissionId']));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'right',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 3,
            submissionId: '8cfe9e24-fe4c-472e-b2eb-3e2c169b11c',
            method: 'POST'));

    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        run: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission (POST)
    streamController.add(ScreenOrientationEvent(0));
    await tester.pump();
    expect(find.byKey(const Key('submit-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-up')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '5');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 1 / 3'), findsOneWidget);

    // Second submission (PATCH)
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data,
        '5 #');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 2 / 3'), findsOneWidget);

    // Third submission (PATCH - incorrect)
    streamController.add(ScreenOrientationEvent(90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-left')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-left')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect. Start over.'), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // Fourth submission (POST - after incorrect, with new orientation)
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '#');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 1 / 3'), findsOneWidget);
  });

  testWidgets(
      'OrientationMemoryGame has different message for first incorrect answer and can be won',
      (WidgetTester tester) async {
    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'up',
            correct: false,
            method: 'POST'));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'right',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 1,
            isComplete: true,
            method: 'POST'));

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        run: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission (POST - incorrect)
    streamController.add(ScreenOrientationEvent(0));
    await tester.pump();
    expect(find.byKey(const Key('submit-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-up')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect.'), findsOneWidget);
    expect(find.text('Start over.'), findsNothing);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // Second submission (POST - correct and winning)
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '#');
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('Progress: 1 / 1'), findsOneWidget);

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
        false);
  });
}
