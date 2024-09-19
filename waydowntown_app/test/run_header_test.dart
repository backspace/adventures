import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/run_header.dart';

void main() {
  testWidgets('GameHeader displays region path and description',
      (WidgetTester tester) async {
    final game = Run(
      id: '1',
      specification: Specification(
        id: '1',
        concept: 'Test',
        placed: true,
        region: Region(
            id: '1',
            name: 'Test Region',
            parentRegion:
                Region(id: '2', name: 'Parent Region', parentRegion: null)),
      ),
      correctSubmissions: 0,
      totalAnswers: 0,
      taskDescription: 'Test description',
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('Test description'), findsOneWidget);
  });

  testWidgets('GameHeader displays countdown when duration is set',
      (WidgetTester tester) async {
    final game = Run(
      id: '1',
      taskDescription: 'Test description',
      specification: Specification(
        id: '1',
        concept: 'Test',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
        duration: 300,
      ),
      correctSubmissions: 0,
      totalAnswers: 0,
      startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Test Region'), findsOneWidget);
    expect(find.textContaining('Time remaining:'), findsOneWidget);
  });

  testWidgets('GameHeader does not display countdown when duration is not set',
      (WidgetTester tester) async {
    final game = Run(
      id: '1',
      taskDescription: 'Test description',
      specification: Specification(
        id: '1',
        concept: 'Test',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
      ),
      correctSubmissions: 0,
      totalAnswers: 0,
      startedAt: DateTime.now(),
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));

    expect(find.text('Test Region'), findsOneWidget);
    expect(find.textContaining('Time remaining:'), findsNothing);
  });

  testWidgets('GameHeader displays "Out of time!" when timer runs out',
      (WidgetTester tester) async {
    final game = Run(
      id: '1',
      taskDescription: 'Test description',
      specification: Specification(
        id: '1',
        concept: 'Test',
        placed: true,
        region: Region(id: '1', name: 'Test Region', parentRegion: null),
        duration: 3,
      ),
      correctSubmissions: 0,
      totalAnswers: 0,
      startedAt: DateTime.now().subtract(const Duration(seconds: 2)),
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Out of time!'), findsOneWidget);
  });

  testWidgets('GameHeader shows progress', (WidgetTester tester) async {
    final game = Run(
      id: '1',
      specification: Specification(
          id: '1',
          concept: 'Test',
          placed: true,
          region: Region(
            id: '1',
            name: 'Test Region',
          )),
      correctSubmissions: 1,
      totalAnswers: 2,
      taskDescription: 'Test description',
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));

    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('GameHeader shows no progress for single-answer',
      (WidgetTester tester) async {
    final game = Run(
      id: '1',
      specification: Specification(
          id: '1',
          concept: 'Test',
          placed: true,
          region: Region(
            id: '1',
            name: 'Test Region',
          )),
      correctSubmissions: 0,
      totalAnswers: 1,
    );

    await tester.pumpWidget(MaterialApp(home: RunHeader(run: game)));

    expect(find.text('0/1'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
