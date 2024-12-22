import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/food_court_frenzy.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';
import '../test_helpers.mocks.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/submissions';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run run;
  late MockPhoenixChannel mockChannel;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    run = TestHelpers.createMockRun(
      concept: 'food_court_frenzy',
      description: 'Find food court items',
      answers: [
        const Answer(id: '1', label: 'Burger'),
        const Answer(id: '2', label: 'Pizza'),
        const Answer(id: '3', label: 'Sushi'),
      ],
    );

    (_, mockChannel, _) = TestHelpers.setupMockSocket();
  });

  testWidgets('FoodCourtFrenzyGame displays and submits answers',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'Jortle',
        answerId: run.specification.answers![0].id,
        correct: true,
        correctSubmissions: 1,
        totalAnswers: 3,
      ),
    );
    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'Margherita',
        answerId: run.specification.answers![1].id,
        correct: true,
        correctSubmissions: 2,
        totalAnswers: 3,
      ),
    );
    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'California Roll',
        answerId: run.specification.answers![2].id,
        correct: true,
        correctSubmissions: 3,
        totalAnswers: 3,
        isComplete: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FoodCourtFrenzyGame(run: run, dio: dio, channel: mockChannel),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('Find food court items'), findsOneWidget);

    // Submit first answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Burger').last, 'Jortle');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Burger'), findsNothing);
    expect(find.text('Jortle'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsOneWidget);

    // Submit second answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Pizza').last, 'Margherita');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Pizza'), findsNothing);
    expect(find.text('Margherita'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsNWidgets(2));

    // Submit third answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Sushi').last, 'California Roll');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sushi'), findsNothing);
    expect(find.text('California Roll'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsNWidgets(3));
    expect(find.text('Congratulations! You have completed the game.'),
        findsOneWidget);

    // Verify labels and answers are still visible
    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Jortle'), findsOneWidget);
  });

  testWidgets('FoodCourtFrenzyGame handles incorrect answers',
      (WidgetTester tester) async {
    TestHelpers.setupMockSubmissionResponse(
      dioAdapter,
      SubmissionRequest(
        route: submitAnswerRoute,
        submission: 'Wrong',
        submissionId: run.specification.answers![0].id,
        correct: false,
        correctSubmissions: 0,
        totalAnswers: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FoodCourtFrenzyGame(run: run, dio: dio, channel: mockChannel),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(ListTile, 'Burger').last, 'Wrong');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Burger'), findsOneWidget);
    expect(find.text('Wrong'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsNothing);

    // Verify that the incorrect message disappears when typing a new answer
    await tester.enterText(find.widgetWithText(ListTile, 'Burger').last, 'New');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect answer. Try again.'), findsNothing);
  });

  testWidgets('FoodCourtFrenzyGame shows errors', (WidgetTester tester) async {
    Run singleAnswerGame = TestHelpers.createMockRun(
      concept: 'food_court_frenzy',
      description: 'Find food court items',
      answers: [
        const Answer(id: '1', label: 'Answer 1'),
      ],
    );

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
      data: TestHelpers.generateSubmissionRequestJson("Error",
          singleAnswerGame.id, singleAnswerGame.specification.answers![0].id),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FoodCourtFrenzyGame(
          run: singleAnswerGame,
          dio: dio,
          channel: mockChannel,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(ListTile, 'Answer 1').last, 'Error');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    TextField textField = tester.widget(find.byType(TextField));
    expect(textField.decoration?.errorText,
        'DioException [unknown]: null\nError: Server error');
  });

  testWidgets('FoodCourtFrenzyGame handles hints', (WidgetTester tester) async {
    const hintRoute = '/waydowntown/reveals';

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
              'hint': 'This is a test hint',
            },
          }
        ]
      }),
      data: {
        'data': {
          'type': 'reveals',
          'attributes': {},
          'relationships': {
            'answer': {
              'data': {'type': 'answers', 'id': '1'}
            }
          }
        }
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FoodCourtFrenzyGame(run: run, dio: dio, channel: mockChannel),
      ),
    );
    await tester.pumpAndSettle();

    await tester
        .tap(find.widgetWithIcon(IconButton, Icons.lightbulb_outline).first);

    await tester.pumpAndSettle();

    expect(find.text('Hint: This is a test hint'), findsOneWidget);

    expect(find.widgetWithIcon(IconButton, Icons.lightbulb_outline),
        findsNWidgets(2));
  });
}
