import 'dart:io' show Platform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Where the "update available" banner sends a player to fetch a newer build.
/// The app is sandboxed and can't self-update, so this just opens the store /
/// testing channel it was installed from (TestFlight on iOS, Play on Android).
///
/// The URLs are NOT committed. They're injected at build time the same way as
/// [API_ROOT]/[SENTRY_DSN]: a `--dart-define` (set by Fastlane from its
/// gitignored `.env.fastlane`), falling back to a `dotenv` `.env.local` for
/// local runs. Their values are the server's `ONBOARDING_IOS_INSTALL` /
/// `ONBOARDING_ANDROID_INSTALL`. When neither is set the banner simply drops
/// its Update button (still dismissible).
const String _iosInstallFromBuild =
    String.fromEnvironment('IOS_INSTALL_URL', defaultValue: '');
const String _androidInstallFromBuild =
    String.fromEnvironment('ANDROID_INSTALL_URL', defaultValue: '');

class InstallLinks {
  /// The update URL for the running platform, or null when unset or on a
  /// platform with no distribution channel (desktop/web).
  static String? get updateUrl {
    if (Platform.isIOS) {
      return _resolve(_iosInstallFromBuild, 'IOS_INSTALL_URL');
    }
    if (Platform.isAndroid) {
      return _resolve(_androidInstallFromBuild, 'ANDROID_INSTALL_URL');
    }
    return null;
  }

  static String? _resolve(String fromBuild, String key) {
    if (fromBuild.isNotEmpty) return fromBuild;
    final fromEnv = dotenv.maybeGet(key);
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return null;
  }
}
