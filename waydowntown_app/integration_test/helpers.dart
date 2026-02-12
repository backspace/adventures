import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] matches at least one widget, or throws on timeout.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException(
      'Timed out waiting for $finder', timeout);
}
