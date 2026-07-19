import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:landgrab/flavors.dart';
import 'package:landgrab/services/user_service.dart';

const String _apiRootFromBuild =
    String.fromEnvironment('API_ROOT', defaultValue: '');

/// Singleton that owns the current API root. Listened to by App.dart, which
/// rebuilds its subtree (new Dio, new LandgrabApi, fresh routes) whenever this
/// changes. Tokens are kept separately per env in UserService, so switching
/// envs back and forth picks up whichever session was last established for
/// that env without forcing a re-login.
class EnvService {
  EnvService._();
  static final EnvService instance = EnvService._();

  final ValueNotifier<String?> currentApiRoot = ValueNotifier(null);

  /// Bumped to force App to rebuild its subtree without changing the env
  /// — used by the account switcher, which swaps the active session in
  /// place (same api root, different user).
  final ValueNotifier<int> sessionEpoch = ValueNotifier(0);

  void restartSession() => sessionEpoch.value++;

  /// Resolve and apply the active API root, taking the user's saved override
  /// into account first.
  Future<String> initialize() async {
    var override = await UserService.getApiRootOverride();
    // Drop a persisted override left by a *different* build flavor — e.g. a
    // staging switch made in one build carried into a production install, or
    // a legacy override with no recorded flavor. An override set within the
    // current flavor is deliberate (testing) and kept, so a production build
    // can still be pointed at staging on purpose. This just stops a stale
    // pin from silently outliving a deploy.
    if (override != null && override.isNotEmpty) {
      final setFlavor = await UserService.getApiRootOverrideFlavor();
      if (setFlavor != F.name) {
        await UserService.setApiRootOverride(null);
        override = null;
      }
    }
    final root = _resolve(override);
    UserService.setCurrentApiRoot(root);
    currentApiRoot.value = root;
    return root;
  }

  /// Switch envs. Pass null to clear the override and revert to the build
  /// default. Returns the resolved new API root.
  Future<String> switchTo(String? override) async {
    // Record which flavor made this switch, so a later install of a
    // different flavor drops it (see [initialize]).
    await UserService.setApiRootOverride(override, flavor: F.name);
    final root = _resolve(override);
    UserService.setCurrentApiRoot(root);
    currentApiRoot.value = root;
    return root;
  }

  String _resolve(String? override) {
    if (override != null && override.isNotEmpty) return override;
    if (_apiRootFromBuild.isNotEmpty) return _apiRootFromBuild;
    final fromEnv = dotenv.maybeGet('API_ROOT');
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return 'http://localhost:4000';
  }
}
