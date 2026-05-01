import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:poles/app.dart';
import 'package:poles/flavors.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  F.appFlavor ??= Flavor.local;

  final sentryDsn = dotenv.maybeGet('SENTRY_DSN');
  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment = F.name;
      },
      appRunner: () => runApp(const App()),
    );
  } else {
    runApp(const App());
  }
}
