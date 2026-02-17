import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] matches at least one widget, or throws on timeout.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
  Finder? failOn,
}) async {
  final end = DateTime.now().add(timeout);
  var lastDump = DateTime.now();
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    if (failOn != null && failOn.evaluate().isNotEmpty) {
      throw TestFailure(
          'Found fail-on widget while waiting for $finder: $failOn');
    }
    // Periodically log all visible text for diagnostics
    if (DateTime.now().difference(lastDump).inSeconds >= 10) {
      lastDump = DateTime.now();
      final texts = <String>[];
      for (final element in find.byType(Text).evaluate()) {
        final widget = element.widget as Text;
        if (widget.data != null) texts.add(widget.data!);
      }
      print('waitFor diagnostic (waiting for $finder): visible texts = $texts');
    }
  }
  // Final dump on timeout
  final texts = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    if (widget.data != null) texts.add(widget.data!);
  }
  print('waitFor TIMEOUT: all visible texts = $texts');
  throw TimeoutException(
      'Timed out waiting for $finder', timeout);
}
