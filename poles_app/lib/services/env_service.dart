import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:poles/services/user_service.dart';

const String _apiRootFromBuild =
    String.fromEnvironment('API_ROOT', defaultValue: '');

/// Singleton that owns the current API root. Listened to by App.dart, which
/// rebuilds its subtree (new Dio, new PolesApi, fresh routes) whenever this
/// changes. Tokens are kept separately per env in UserService, so switching
/// envs back and forth picks up whichever session was last established for
/// that env without forcing a re-login.
class EnvService {
  EnvService._();
  static final EnvService instance = EnvService._();

  final ValueNotifier<String?> currentApiRoot = ValueNotifier(null);

  /// Resolve and apply the active API root, taking the user's saved override
  /// into account first.
  Future<String> initialize() async {
    final override = await UserService.getApiRootOverride();
    final root = _resolve(override);
    UserService.setCurrentApiRoot(root);
    currentApiRoot.value = root;
    return root;
  }

  /// Switch envs. Pass null to clear the override and revert to the build
  /// default. Returns the resolved new API root.
  Future<String> switchTo(String? override) async {
    await UserService.setApiRootOverride(override);
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
