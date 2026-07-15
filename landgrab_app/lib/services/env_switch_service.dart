import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landgrab/flavors.dart';

/// Gate for the in-app environment switcher. Combines two things:
///
///   * A compile-time upper bound — `F.couldAllowEnvSwitch`, currently
///     true for every flavor. (Kept as a hook in case a future build
///     wants to lock the switcher out entirely.)
///   * A runtime unlock — persisted in SharedPreferences and toggled
///     on by an easter egg in the Credits screen (7 taps on the
///     version line). Off by default on every flavor, so a shipped
///     build — production included — never exposes the gear unless
///     someone deliberately performs the gesture. This is what keeps
///     it away from attendees while still letting us flip the real
///     production artifact to staging for testing.
///
/// UI listens to [visible] with `ValueListenableBuilder<bool>` and
/// renders the settings gear / env banner only when it reads true.
class EnvSwitchService {
  EnvSwitchService._();

  static const _storageKey = 'env_switch:unlocked';

  /// Combined visibility flag. Guaranteed false in production builds
  /// and false-until-unlock elsewhere.
  static final ValueNotifier<bool> visible = ValueNotifier(false);

  /// Read the persisted unlock state and update [visible]. Call once
  /// during app bootstrap.
  static Future<void> load() async {
    if (!F.couldAllowEnvSwitch) return;
    final prefs = await SharedPreferences.getInstance();
    visible.value = prefs.getBool(_storageKey) ?? false;
  }

  /// Persist the unlock and flip [visible] to true. Silently no-ops
  /// in production so a stray call site can't defeat the compile-
  /// time gate.
  static Future<void> unlock() async {
    if (!F.couldAllowEnvSwitch) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_storageKey, true);
    visible.value = true;
  }
}
