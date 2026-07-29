import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/local_auth.dart';

/// Device-auth gate for the offline viewer. Requires a Face ID / Touch ID /
/// device-passcode check before the stored (decrypted) content is shown, so a
/// found or borrowed unlocked phone still can't browse it — the "password" is
/// the device unlock the user already has, nothing to remember.
class ViewerAuth {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the user may proceed.
  ///
  /// - If the device has no lock at all (no biometrics *and* no passcode) there
  ///   is nothing to gate on, so allow — locking the user out of their own data
  ///   for lack of a passcode helps no one.
  /// - Any error from the auth machinery (lockout, mid-flight un-enrollment)
  ///   fails **closed** — the caller can simply try again.
  static Future<bool> unlock({
    String reason = 'Unlock the local data viewer',
  }) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device passcode as a fallback
          stickyAuth: true, // survive an app backgrounding mid-prompt
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
