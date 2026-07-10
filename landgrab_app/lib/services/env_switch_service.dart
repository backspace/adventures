import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:landgrab/flavors.dart';

/// Gate for the in-app environment switcher. Combines two things:
///
///   * A compile-time upper bound — `F.couldAllowEnvSwitch`. Production
///     builds never show the switcher regardless of unlock state, so
///     shipping a Play/App Store build can't accidentally reveal it.
///   * A runtime unlock — persisted in SharedPreferences and toggled
///     on by an easter egg in the Credits screen (7 taps on the
///     version line). Off by default even on dev/alpha, so a build
///     handed to a demo tester doesn't start with the gear exposed.
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
