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
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';

import 'cardinal_memory_test.mocks.dart';

@GenerateMocks([MotionSensors])
void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/answers';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run game;
  late MockMotionSensors mockMotionSensors;

  setUp(() {
    mockMotionSensors = MockMotionSensors();
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockGame(concept: 'cardinal_memory');
  });

  testWidgets('CardinalMemoryGame displays and submits pattern',
      (WidgetTester tester) async {
    final ids1 = TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'north',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 3,
            method: 'POST'));

    final ids2 = TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: '/waydowntown/answers/${ids1['answerId']}',
            answer: 'north|west',
            correct: true,
            correctAnswers: 2,
            totalAnswers: 3,
            method: 'PATCH',
            gameId: ids1['gameId'],
            answerId: ids1['answerId']));

    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: '/waydowntown/answers/${ids2['answerId']}',
            answer: 'north|west|south',
            correct: false,
            method: 'PATCH',
            gameId: ids1['gameId'],
            answerId: ids2['answerId']));

    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'west',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 3,
            answerId: '8cfe9e24-fe4c-472e-b2eb-3e2c169b11c',
            method: 'POST'));

    final streamController = StreamController<AbsoluteOrientationEvent>();
    when(mockMotionSensors.absoluteOrientation)
        .thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: CardinalMemoryGame(
        dio: dio,
        game: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission (POST)
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

    // Second submission (PATCH)
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

    // Third submission (PATCH - incorrect)
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

    // Fourth submission (POST - after incorrect, with new direction)
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

    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'north',
            correct: false,
            method: 'POST'));
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'west',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 1,
            isComplete: true,
            method: 'POST'));

    await tester.pumpWidget(MaterialApp(
      home: CardinalMemoryGame(
        dio: dio,
        game: game,
        motionSensors: mockMotionSensors,
      ),
    ));

    expect(find.text('Current pattern: '), findsOneWidget);
    expect(find.byKey(const Key('pattern-arrows')), findsOneWidget);
    expect(find.byKey(const Key('progress-display')), findsOneWidget);
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // First submission (POST - incorrect)
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
    expect(find.text('Progress: 0 / 3'), findsOneWidget);

    // Second submission (POST - correct and winning)
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
