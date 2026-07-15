enum Flavor { dev, alpha, production }

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'LNDGRB (dev)';
      case Flavor.alpha:
        return 'LNDGRB (alpha)';
      case Flavor.production:
        return 'LNDGRB';
      default:
        return 'LNDGRB';
    }
  }

  static Flavor fromName(String name) {
    return switch (name) {
      'alpha' => Flavor.alpha,
      'production' => Flavor.production,
      _ => Flavor.dev,
    };
  }

  /// Whether the current flavor is even *allowed* to show the env
  /// switcher. All flavors answer true, but the switcher is gated by
  /// a runtime unlock (see `EnvSwitchService.visible`) — a 7-tap
  /// easter egg on the Credits version line, off by default. So even
  /// a production build never shows the switcher unless someone
  /// deliberately hunts for the egg; this just lets us flip the
  /// shipped production artifact to staging for testing rather than
  /// locking it out at compile time.
  static bool get couldAllowEnvSwitch => true;
}
