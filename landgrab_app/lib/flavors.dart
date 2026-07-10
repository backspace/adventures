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
  /// switcher. Production builds always answer false. Dev / alpha
  /// answer true but the switcher is additionally gated by a runtime
  /// unlock (see `EnvSwitchService.visible`) — this getter is the
  /// compile-time upper bound, not the "should be visible right now"
  /// signal.
  static bool get couldAllowEnvSwitch =>
      appFlavor == Flavor.dev || appFlavor == Flavor.alpha;
}
