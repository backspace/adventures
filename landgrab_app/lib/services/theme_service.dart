import 'package:flutter/material.dart';

import 'package:landgrab/services/ui_preferences.dart';

/// The app-wide light/dark preference. [App] listens to [mode] and drives
/// MaterialApp's `themeMode` off it; the Settings screen writes to it. Defaults
/// to [ThemeMode.system] until [load] reads the persisted choice.
class ThemeService {
  ThemeService._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  /// Read the saved preference and update [mode]. Call once at bootstrap.
  static Future<void> load() async {
    mode.value = _parse(await UiPreferences.getThemeMode());
  }

  /// Apply and persist a new preference.
  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    await UiPreferences.setThemeMode(m.name); // "system" / "light" / "dark"
  }

  static ThemeMode _parse(String? s) => switch (s) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
