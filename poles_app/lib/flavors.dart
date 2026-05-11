enum Flavor { dev, alpha, production }

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'POLES (dev)';
      case Flavor.alpha:
        return 'POLES (alpha)';
      case Flavor.production:
        return 'Poles';
      default:
        return 'Poles';
    }
  }

  static Flavor fromName(String name) {
    return switch (name) {
      'alpha' => Flavor.alpha,
      'production' => Flavor.production,
      _ => Flavor.dev,
    };
  }

  /// Whether the in-app environment switcher should be available.
  /// Only true in dev and alpha builds.
  static bool get allowsEnvSwitch =>
      appFlavor == Flavor.dev || appFlavor == Flavor.alpha;
}
