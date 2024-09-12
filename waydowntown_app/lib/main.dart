import 'dart:async';
import 'package:flutter/material.dart';
import 'app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter/foundation.dart';

FutureOr<void> main() async {
  Logger.level = kDebugMode ? Level.debug : Level.warning;

  if (dotenv.env['SENTRY_DSN'] != null) {
    await SentryFlutter.init(
      (options) {
        options.dsn = dotenv.env['SENTRY_DSN']!;
        options.tracesSampleRate = 1.0;
        options.profilesSampleRate = 1.0;
      },
      appRunner: () => runApp(const Waydowntown()),
    );
  }

  runApp(const Waydowntown());
}
