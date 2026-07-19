/// App version + build, read once at startup ([main]) and attached to every
/// API request as an `X-Client-Version` header. Lets the server record which
/// client builds are live (see the server's TelemetryController) — cheap
/// visibility into version drift, which matters because compat breaks usually
/// surface as *handled* errors the app catches, so they never reach Sentry.
class AppInfo {
  AppInfo._();

  static String version = '';
  static String build = '';

  /// e.g. `1.0.0+2403`. Empty parts render as `?` so a missing value shows up
  /// rather than silently blank. Empty overall until [main] populates it.
  static String get clientVersion {
    if (version.isEmpty && build.isEmpty) return '';
    return '${version.isEmpty ? '?' : version}+${build.isEmpty ? '?' : build}';
  }
}
