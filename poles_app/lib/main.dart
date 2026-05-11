import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:poles/app.dart';
import 'package:poles/flavors.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _flavorFromBuild =
    String.fromEnvironment('FLAVOR_NAME', defaultValue: 'dev');
const String _sentryDsnFromBuild =
    String.fromEnvironment('SENTRY_DSN', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env.local');
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // No env file is fine — build-time --dart-define values still apply
      // and EnvService falls back to localhost as a last resort.
    }
  }
  F.appFlavor = F.fromName(_flavorFromBuild);

  final sentryDsn = _sentryDsnFromBuild.isNotEmpty
      ? _sentryDsnFromBuild
      : dotenv.maybeGet('SENTRY_DSN');

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

