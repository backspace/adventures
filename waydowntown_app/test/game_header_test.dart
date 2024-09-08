import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/game_header.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

void main() {
  testWidgets('GameHeader displays region path', (WidgetTester tester) async {
    final game = Game(
      id: '1',
      incarnation: Incarnation(
        id: '1',
        concept: 'Test',
        description: 'Test description',
        placed: true,
        region: Region(
            id: '1',
            name: 'Test Region',
            parentRegion:
                Region(id: '2', name: 'Parent Region', parentRegion: null)),
      ),
      correctAnswers: 0,
      totalAnswers: 0,
    );

    await tester.pumpWidget(MaterialApp(home: GameHeader(game: game)));

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
  });

  testWidgets('GameHeader displays countdown when duration is set',
      (WidgetTester tester) async {
    final game = Game(
      id: '1',
      incarnation: Incarnation(
        id: '1',
        concept: 'Test',
        description: 'Test description',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
        durationSeconds: 300,
      ),
      correctAnswers: 0,
      totalAnswers: 0,
      startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    );

    await tester.pumpWidget(MaterialApp(home: GameHeader(game: game)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Test Region'), findsOneWidget);
    expect(find.textContaining('Time remaining:'), findsOneWidget);
  });

  testWidgets('GameHeader does not display countdown when duration is not set',
      (WidgetTester tester) async {
    final game = Game(
      id: '1',
      incarnation: Incarnation(
        id: '1',
        concept: 'Test',
        description: 'Test description',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
      ),
      correctAnswers: 0,
      totalAnswers: 0,
      startedAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(home: GameHeader(game: game)));

    expect(find.text('Test Region'), findsOneWidget);
    expect(find.textContaining('Time remaining:'), findsNothing);
  });

  testWidgets('GameHeader displays "Out of time!" when timer runs out',
      (WidgetTester tester) async {
    final game = Game(
      id: '1',
      incarnation: Incarnation(
        id: '1',
        concept: 'Test',
        description: 'Test description',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
        durationSeconds: 3,
      ),
      correctAnswers: 0,
      totalAnswers: 0,
      startedAt: DateTime.now().subtract(const Duration(seconds: 2)),
    );

    await tester.pumpWidget(MaterialApp(home: GameHeader(game: game)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Out of time!'), findsOneWidget);
  });
}
