import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/games/food_court_frenzy.dart';
import 'package:waydowntown/models/run.dart';

import '../test_helpers.dart';

void main() {
  dotenv.testLoad(fileInput: File('.env').readAsStringSync());

  const submitAnswerRoute = '/waydowntown/answers';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Run game;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockGame(
      concept: 'food_court_frenzy',
      description: 'Find food court items',
      answerLabels: ['Burger', 'Pizza', 'Sushi'],
    );
  });

  testWidgets('FoodCourtFrenzyGame displays and submits answers',
      (WidgetTester tester) async {
    TestHelpers.setupMockAnswerResponse(
      dioAdapter,
      AnswerRequest(
        route: submitAnswerRoute,
        answer: 'Burger|Jortle',
        correct: true,
        correctAnswers: 1,
        totalAnswers: 3,
      ),
    );
    TestHelpers.setupMockAnswerResponse(
      dioAdapter,
      AnswerRequest(
        route: submitAnswerRoute,
        answer: 'Pizza|Margherita',
        correct: true,
        correctAnswers: 2,
        totalAnswers: 3,
      ),
    );
    TestHelpers.setupMockAnswerResponse(
      dioAdapter,
      AnswerRequest(
        route: submitAnswerRoute,
        answer: 'Sushi|California Roll',
        correct: true,
        correctAnswers: 3,
        totalAnswers: 3,
        isComplete: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: FoodCourtFrenzyGame(game: game, dio: dio)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('Find food court items'), findsOneWidget);
    expect(find.text('Progress: 0/3'), findsOneWidget);

    // Submit first answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Burger').last, 'Jortle');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.text('Progress: 1/3'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Burger'), findsNothing);
    expect(find.text('Jortle'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsOneWidget);

    // Submit second answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Pizza').last, 'Margherita');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.text('Progress: 2/3'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Pizza'), findsNothing);
    expect(find.text('Margherita'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsNWidgets(2));

    // Submit third answer
    await tester.enterText(
        find.widgetWithText(ListTile, 'Sushi').last, 'California Roll');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.text('Progress: 3/3'), findsOneWidget);
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
    TestHelpers.setupMockAnswerResponse(
      dioAdapter,
      AnswerRequest(
        route: submitAnswerRoute,
        answer: 'Burger|Wrong',
        correct: false,
        correctAnswers: 0,
        totalAnswers: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: FoodCourtFrenzyGame(game: game, dio: dio)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(ListTile, 'Burger').last, 'Wrong');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    expect(find.text('Progress: 0/3'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Burger'), findsOneWidget);
    expect(find.text('Wrong'), findsOneWidget);
    expect(find.widgetWithIcon(ListTile, Icons.check_circle), findsNothing);

    // Verify that the incorrect message disappears when typing a new answer
    await tester.enterText(find.widgetWithText(ListTile, 'Burger').last, 'New');
    await tester.pumpAndSettle();
    expect(find.text('Incorrect answer. Try again.'), findsNothing);
  });

  testWidgets('FoodCourtFrenzyGame shows errors', (WidgetTester tester) async {
    Run singleAnswerGame = TestHelpers.createMockGame(
      concept: 'food_court_frenzy',
      description: 'Find food court items',
      answerLabels: ['Burger'],
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
      data: TestHelpers.generateAnswerRequestJson(
          "Burger|Error", singleAnswerGame.id),
    );

    await tester.pumpWidget(
      MaterialApp(home: FoodCourtFrenzyGame(game: singleAnswerGame, dio: dio)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(ListTile, 'Burger').last, 'Error');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.send).first);
    await tester.pumpAndSettle();

    TextField textField = tester.widget(find.byType(TextField));
    expect(textField.decoration?.errorText,
        'DioException [unknown]: null\nError: Server error');
  });
}
