import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/games/collector_game.dart';
import 'package:waydowntown/widgets/sensor_answer_scanner.dart';

class MockStringDetector implements StringDetector {
  final _controller = StreamController<String>.broadcast();
  bool started = false;
  bool disposed = false;

  @override
  Stream<String> get detectedStrings => _controller.stream;

  @override
  void startDetecting() {
    started = true;
  }

  @override
  void stopDetecting() {}

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }

  void emit(String value) {
    _controller.add(value);
  }
}

void main() {
  testWidgets('detected items appear in the list', (tester) async {
    final detector = MockStringDetector();
    List<ScannedAnswer>? result;

    await tester.pumpWidget(MaterialApp(
      home: SensorAnswerScanner(
        detector: detector,
        inputBuilder: (_, __) => const SizedBox(),
        title: 'Test Scanner',
      ),
    ));

    expect(find.text('Test Scanner'), findsOneWidget);
    expect(find.text('Scanning...'), findsOneWidget);
    expect(detector.started, isTrue);

    detector.emit('Device A');
    await tester.pump();

    expect(find.text('Device A'), findsOneWidget);
    expect(find.text('Scanning...'), findsNothing);

    detector.emit('Device B');
    await tester.pump();

    expect(find.text('Device A'), findsOneWidget);
    expect(find.text('Device B'), findsOneWidget);
  });

  testWidgets('duplicate values are deduplicated', (tester) async {
    final detector = MockStringDetector();

    await tester.pumpWidget(MaterialApp(
      home: SensorAnswerScanner(
        detector: detector,
        inputBuilder: (_, __) => const SizedBox(),
        title: 'Test Scanner',
      ),
    ));

    detector.emit('Device A');
    await tester.pump();
    detector.emit('Device A');
    await tester.pump();
    detector.emit('Device A');
    await tester.pump();

    expect(find.text('Device A'), findsOneWidget);
  });

  testWidgets('toggling include and entering a hint', (tester) async {
    final detector = MockStringDetector();

    await tester.pumpWidget(MaterialApp(
      home: SensorAnswerScanner(
        detector: detector,
        inputBuilder: (_, __) => const SizedBox(),
        title: 'Test Scanner',
      ),
    ));

    detector.emit('Device A');
    await tester.pump();

    // Hint field not visible before including
    expect(find.byKey(const Key('hint-0')), findsNothing);

    // Toggle include
    await tester.tap(find.byKey(const Key('include-0')));
    await tester.pump();

    // Hint field is now visible
    expect(find.byKey(const Key('hint-0')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('hint-0')), 'Near entrance');
    await tester.pump();

    // Toggle off
    await tester.tap(find.byKey(const Key('include-0')));
    await tester.pump();

    expect(find.byKey(const Key('hint-0')), findsNothing);
  });

  testWidgets('Done returns only included items as ScannedAnswer list',
      (tester) async {
    final detector = MockStringDetector();
    List<ScannedAnswer>? result;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(context).push<List<ScannedAnswer>>(
              MaterialPageRoute(
                builder: (context) => SensorAnswerScanner(
                  detector: detector,
                  inputBuilder: (_, __) => const SizedBox(),
                  title: 'Test Scanner',
                ),
              ),
            );
          },
          child: const Text('Open Scanner'),
        ),
      ),
    ));

    await tester.tap(find.text('Open Scanner'));
    await tester.pumpAndSettle();

    detector.emit('Device A');
    await tester.pump();
    detector.emit('Device B');
    await tester.pump();
    detector.emit('Device C');
    await tester.pump();

    // List order is newest first: [C(0), B(1), A(2)]
    expect(find.text('Device C'), findsOneWidget);
    expect(find.text('Device B'), findsOneWidget);
    expect(find.text('Device A'), findsOneWidget);

    // Include Device A (index 2) with hint
    await tester.tap(find.byKey(const Key('include-2')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('hint-2')), 'Lobby');

    // Include Device C (index 0) without hint
    await tester.tap(find.byKey(const Key('include-0')));
    await tester.pump();

    // Don't include Device B

    await tester.tap(find.byKey(const Key('scanner-done')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.length, equals(2));

    // _buildResult iterates _entries in order: [C, B, A], filtering included
    // Device A is included first in iteration (index 2), Device C second (index 0)
    // Actually entries list is [C, B, A], so iteration yields A first? No.
    // _entries order: insert(0,...) so C is at 0, B at 1, A at 2
    // .where(included) iterates: C(included), B(not), A(included) => [C, A]
    expect(result![0].answer, equals('Device C'));
    expect(result![0].hint, isNull);
    expect(result![1].answer, equals('Device A'));
    expect(result![1].hint, equals('Lobby'));
  });
}
