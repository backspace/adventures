import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:landgrab/app.dart';
import 'package:landgrab/app_info.dart';
import 'package:landgrab/firebase_options.dart';
import 'package:landgrab/flavors.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  // Read the app's version+build once, so every request can announce it via
  // an X-Client-Version header (see AppInfo / the server's telemetry). Failure
  // is non-fatal — the header just goes unset.
  try {
    final info = await PackageInfo.fromPlatform();
    AppInfo.version = info.version;
    AppInfo.build = info.buildNumber;
  } catch (_) {
    // Leave AppInfo empty; the header is simply omitted.
  }

  // Firebase powers push notifications (FCM on Android, FCM→APNs
  // relay on iOS). Init failure is non-fatal — the app works fully
  // without push; PushService just won't register a token.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // e.g. running on a platform flutterfire wasn't configured for.
  }

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

