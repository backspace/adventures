import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/routes/puzzlet_route.dart';

class _FakeApi extends LandgrabApi {
  _FakeApi() : super(Dio(BaseOptions(baseUrl: 'http://test.invalid')));

  AttemptOutcome? nextOutcome;
  String? lastAnswer;
  // What listActivePuzzlets returns — drives _onTeamPuzzletsChanged's
  // "is this puzzlet still ours?" check.
  List<ScanResult> activePuzzlets = const [];

  @override
  Future<AttemptOutcome> submitAnswer(String puzzletId, String answer) async {
    lastAnswer = answer;
    final outcome = nextOutcome;
    if (outcome == null) {
      throw StateError('FakeApi.nextOutcome was not set before submit');
    }
    return outcome;
  }

  @override
  Future<List<ScanResult>> listActivePuzzlets() async => activePuzzlets;
}

Pole _pole() => Pole(
      id: 'p1',
      name: 'Esplanade Riel',
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

  testWidgets(
      'opens in the game-over state when the game has already ended',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(),
      gameEndsAt: DateTime.now().subtract(const Duration(minutes: 1)),
    )));

    // Message shown proactively, and the Submit button + answer field are
    // disabled without any submit attempt.
    expect(find.text(PuzzletStrings.gameOver), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.enabled, isFalse);
  });

  testWidgets('stays interactive when the game end is still in the future',
      (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(_wrap(PuzzletRoute(
      api: api,
      pole: _pole(),
      puzzlet: _puzzlet(),
      gameEndsAt: DateTime.now().add(const Duration(hours: 1)),
    )));

    expect(find.text(PuzzletStrings.gameOver), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('celebrates a correct answer and pops back with `true`',
      (tester) async {
    final api = _FakeApi();
    api.nextOutcome = const AttemptCorrect(captureTeamId: 't1', poleLocked: false);

    // Host the route behind a pushed page so we can observe the pop
    // and its result.
    bool? popResult;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popResult = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PuzzletRoute(
                    api: api,
                    pole: _pole(),
                    puzzlet: _puzzlet(),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Red');
    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    // No success text; the CLAIMED stamp carries the feedback while
    // the celebration plays.
    expect(find.textContaining('Correct'), findsNothing);
    expect(find.text('CLAIMED'), findsOneWidget);

    // After the celebration window, the route pops with `true` so the
    // scan flow can tell the map which pole to animate.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzletRoute), findsNothing);
    expect(popResult, isTrue);
  });

  testWidgets(
      'a teammate resolving the puzzlet returns to the map even with a scanner '
      'pushed on top (no freeze)', (tester) async {
    final api = _FakeApi();
    // The puzzlet is no longer in the team's active list — it was resolved.
    api.activePuzzlets = const [];
    final changed = StreamController<String>.broadcast();
    addTearDown(changed.close);

    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PuzzletRoute(
                api: api,
                pole: _pole(),
                puzzlet: _puzzlet(),
                teamPuzzletsChanged: changed.stream,
                teamId: 'team-1',
              ),
            )),
            child: const Text('MAP'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('MAP'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzletRoute), findsOneWidget);

    // Simulate the barcode / NFC answer scanner pushed on top of the puzzlet.
    navKey.currentState!.push(MaterialPageRoute(
      builder: (_) => const Scaffold(body: Text('SCANNER')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('SCANNER'), findsOneWidget);

    // A teammate resolves the puzzlet: team_puzzlets_changed fires and it's no
    // longer ours. Before the fix, the pop landed on the scanner and stranded
    // the player on the defunct puzzlet — now both unwind back to the map.
    changed.add('team-1');
    await tester.pumpAndSettle();

    expect(find.text('SCANNER'), findsNothing);
    expect(find.byType(PuzzletRoute), findsNothing);
    expect(find.text('MAP'), findsOneWidget);
  });
}
