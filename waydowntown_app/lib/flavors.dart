enum Flavor {
  local,
  production,
}

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.local:
        return 'LOCAL';
      case Flavor.production:
        return 'waydown';
      default:
        return 'title';
    }
  }

}
