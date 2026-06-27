enum Flavor { dev, alpha, production }

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'LANDGRAB (dev)';
      case Flavor.alpha:
        return 'LANDGRAB (alpha)';
      case Flavor.production:
        return 'LANDGRAB';
      default:
        return 'LANDGRAB';
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
