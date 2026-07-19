import 'package:flutter/material.dart';

/// Brightness-aware colours for a semantic "accent" alert box — amber for
/// warnings, blue for info/contested, purple for review. Light mode uses a
/// pale tint with dark ink; dark mode uses a muted dark tint with light ink —
/// so these boxes read on both light and dark chrome without hardcoding a
/// single fixed palette that only worked in light mode.
class AccentColors {
  final Color fill;
  final Color border;
  final Color ink;

  const AccentColors({
    required this.fill,
    required this.border,
    required this.ink,
  });

  factory AccentColors.of(BuildContext context, MaterialColor swatch) =>
      AccentColors.forBrightness(Theme.of(context).brightness, swatch);

  factory AccentColors.forBrightness(
      Brightness brightness, MaterialColor swatch) {
    if (brightness == Brightness.dark) {
      return AccentColors(
        fill: swatch.shade900.withValues(alpha: 0.32),
        border: swatch.shade400.withValues(alpha: 0.55),
        ink: swatch.shade100,
      );
    }
    return AccentColors(
      fill: swatch.shade50,
      border: swatch.shade300,
      ink: swatch.shade900,
    );
  }
}
