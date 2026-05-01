import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';
import 'package:poles/routes/puzzlet_route.dart';

class _FakeApi extends PolesApi {
  _FakeApi() : super(Dio(BaseOptions(baseUrl: 'http://test.invalid')));

  AttemptOutcome? nextOutcome;
  String? lastAnswer;

  @override
  Future<AttemptOutcome> submitAnswer(String puzzletId, String answer) async {
    lastAnswer = answer;
    final outcome = nextOutcome;
    if (outcome == null) {
      throw StateError('FakeApi.nextOutcome was not set before submit');
    }
    return outcome;
  }
}

Pole _pole() => Pole(
      id: 'p1',
      barcode: 'POLE-004',
      label: 'Esplanade Riel',
      latitude: 49.8898,
      longitude: -97.1267,
      currentOwnerTeamId: null,
      locked: false,
    );

Puzzlet _puzzlet({
  int attemptsRemaining = 3,
  List<String> previousWrongAnswers = const [],
}) =>
    Puzzlet(
      id: 'pz1',
      instructions: 'Which river does this pedestrian bridge cross?',
      difficulty: 1,
      attemptsRemaining: attemptsRemaining,
      previousWrongAnswers: previousWrongAnswers,
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('renders previous wrong answers when present',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(
        attemptsRemaining: 2,
        previousWrongAnswers: ['Assiniboine', 'green'],
      ),
    )));

    expect(find.text('Already tried by your team:'), findsOneWidget);
    expect(find.text('Assiniboine'), findsOneWidget);
    expect(find.text('green'), findsOneWidget);
    expect(find.text('Attempts remaining: 2'), findsOneWidget);
  });

  testWidgets('hides the previous-wrong-answers card when list is empty',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(),
    )));

    expect(find.text('Already tried by your team:'), findsNothing);
  });

  testWidgets('appends a new wrong answer to the list and clears the input',
      (tester) async {
    final api = _FakeApi();
    api.nextOutcome = const AttemptIncorrect(
      attemptsRemaining: 1,
      previousWrongAnswers: ['blue', 'red'],
    );

    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(
        attemptsRemaining: 2,
        previousWrongAnswers: ['blue'],
      ),
    )));

    await tester.enterText(find.byType(TextField), 'red');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(api.lastAnswer, 'red');
    expect(find.text('blue'), findsOneWidget);
    expect(find.text('red'), findsOneWidget);
    expect(find.text('Attempts remaining: 1'), findsOneWidget);
    expect(find.text('Incorrect. 1 attempt(s) left.'), findsOneWidget);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });

  testWidgets('disables Submit when attempts run out', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(attemptsRemaining: 0),
    )));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('shows capture message after a correct answer', (tester) async {
    final api = _FakeApi();
    api.nextOutcome = const AttemptCorrect(captureTeamId: 't1', poleLocked: false);

    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(),
    )));

    await tester.enterText(find.byType(TextField), 'Red');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Correct! Pole captured.'), findsOneWidget);
  });
}
