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
import 'package:waydowntown/games/cardinal_memory.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';

import 'cardinal_memory_test.mocks.dart';

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
    game = TestHelpers.createMockRun(concept: 'cardinal_memory', answers: [
      const Answer(id: '1', label: 'north', order: 1),
      const Answer(id: '2', label: 'west', order: 2),
      const Answer(id: '3', label: 'south', order: 3),
    ]);
  });

  testWidgets('CardinalMemoryGame displays and submits pattern',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'north',
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
            submission: 'west',
            correct: true,
            correctSubmissions: 2,
            totalAnswers: 3,
            runId: game.id,
            answerId: '2'));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
            route: submitAnswerRoute,
            submission: 'south',
            correct: false,
            correctSubmissions: 0,
            totalAnswers: 3,
            runId: game.id,
            answerId: '3'));

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'west',
          correct: true,
          correctSubmissions: 1,
          totalAnswers: 3,
          runId: game.id,
          answerId: '1',
        ));

    final streamController = StreamController<AbsoluteOrientationEvent>();
    when(mockMotionSensors.absoluteOrientation)
        .thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: CardinalMemoryGame(
        dio: dio,
        run: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission
    streamController.add(AbsoluteOrientationEvent(0, 0, 0));
    await tester.pump();
    expect(find.byKey(const Key('submit-north')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-north')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '5');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 1 / 3'), findsOneWidget);

    // Second submission
    streamController.add(AbsoluteOrientationEvent(1.57, 0, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-west')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-west')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data,
        '5 3');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 2 / 3'), findsOneWidget);

    // Third submission: incorrect
    streamController.add(AbsoluteOrientationEvent(3.14, 0, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-south')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-south')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect. Start over.'), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // Fourth submission: after incorrect, with new direction
    streamController.add(AbsoluteOrientationEvent(1.57, 0, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-west')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-west')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pattern-arrows')), findsWidgets);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '3');
    expect(find.text('Correct! Keep going.'), findsOneWidget);
    expect(find.text('Progress: 1 / 3'), findsOneWidget);
  });

  testWidgets(
      'CardinalMemoryGame has different message for first incorrect answer and can be won',
      (WidgetTester tester) async {
    final streamController = StreamController<AbsoluteOrientationEvent>();
    when(mockMotionSensors.absoluteOrientation)
        .thenAnswer((_) => streamController.stream);

    final shortRun =
        TestHelpers.createMockRun(concept: 'cardinal_memory', answers: [
      const Answer(id: '1', label: 'west', order: 1),
    ]);

    TestHelpers.setupMockSubmissionResponse(
        dioAdapter,
        SubmissionRequest(
          route: submitAnswerRoute,
          submission: 'north',
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
          submission: 'west',
          correct: true,
          correctSubmissions: 1,
          totalAnswers: 1,
          runId: shortRun.id,
          answerId: '1',
          isComplete: true,
        ));

    await tester.pumpWidget(MaterialApp(
      home: CardinalMemoryGame(
        dio: dio,
        run: shortRun,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission: incorrect
    streamController.add(AbsoluteOrientationEvent(0, 0, 0));
    await tester.pump();
    expect(find.byKey(const Key('submit-north')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-north')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '');
    expect(find.text('Incorrect.'), findsOneWidget);
    expect(find.text('Start over.'), findsNothing);
    expect(find.text('Progress: 0 / 1'), findsOneWidget);

    // Second submission: correct and winning
    streamController.add(AbsoluteOrientationEvent(1.57, 0, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('submit-west')), findsOneWidget);

    await tester.tap(find.byKey(const Key('submit-west')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(
        tester.widget<Text>(find.byKey(const Key('pattern-arrows'))).data, '3');
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('Progress: 1 / 1'), findsOneWidget);

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
        false);
  });
}
