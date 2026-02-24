import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:dchs_motion_sensors/dchs_motion_sensors.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/orientation_memory.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

import 'orientation_memory_test.mocks.dart';

@GenerateMocks([MotionSensors])
void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/submissions';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run game;
  late MockMotionSensors mockMotionSensors;
  late MockPhoenixChannel mockChannel;

  setUp(() async {
    mockMotionSensors = MockMotionSensors();
    await TestHelpers.setMockUser();
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockRun(concept: 'orientation_memory', answers: [
      const Answer(id: '1', label: 'up', order: 1),
      const Answer(id: '2', label: 'right', order: 2),
      const Answer(id: '3', label: 'left', order: 3),
    ]);

    (_, mockChannel, _) = TestHelpers.setupMockSocket();
  });

  testWidgets('OrientationMemoryGame displays and submits pattern',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'up',
          correct: true,
          correctSubmissions: 1,
          totalAnswers: 3,
          runId: game.id,
          answerId: '1',
        ));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'right',
            correct: true,
            correctSubmissions: 2,
            totalAnswers: 3,
            runId: game.id,
            answerId: '2'));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'left',
            correct: false,
            correctSubmissions: 0,
            totalAnswers: 3,
            runId: game.id,
            answerId: '3'));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'right',
          correct: true,
          correctSubmissions: 1,
          totalAnswers: 3,
          runId: game.id,
          answerId: '1',
        ));

    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        run: game,
        channel: mockChannel,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);

    // First submission
    streamController.add(ScreenOrientationEvent(0));
    await tester.pump();
    expect(find.byKey(const Key('submit-up')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-up')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '5');
    expect(find.text('Correct! Keep going.'), findsOneWidget);

    // Second submission
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data,
        '5 #');
    expect(find.text('Correct! Keep going.'), findsOneWidget);

    // Third submission: incorrect
    streamController.add(ScreenOrientationEvent(90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-left')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-left')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect. Start over.'), findsOneWidget);

    // Fourth submission: after incorrect, with new orientation
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '#');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
  });

  testWidgets(
      'OrientationMemoryGame has different message for first incorrect answer and can be won',
      (WidgetTester tester) async {
    final streamController = StreamController<ScreenOrientationEvent>();
    when(mockMotionSensors.screenOrientation)
        .thenAnswer((_) => streamController.stream);

    final shortRun =
        TestHelpers.createMockRun(concept: 'orientation_memory', answers: [
      const Answer(id: '1', label: 'right', order: 1),
    ]);

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'up',
          correct: false,
          correctSubmissions: 0,
          totalAnswers: 1,
          runId: shortRun.id,
          answerId: '1',
        ));
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'right',
          correct: true,
          correctSubmissions: 1,
          totalAnswers: 1,
          runId: shortRun.id,
          answerId: '1',
          isComplete: true,
        ));

    await tester.pumpWidget(MaterialApp(
      home: OrientationMemoryGame(
        dio: dio,
        run: shortRun,
        channel: mockChannel,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);

    // First submission: incorrect
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

    // Second submission: correct and winning
    streamController.add(ScreenOrientationEvent(-90));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-right')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-right')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '#');
    expect(find.text('Congratulations!'), findsOneWidget);

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
        false);
  });
}
