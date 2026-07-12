import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/services/user_service.dart';
import 'package:logger/logger.dart';

/// Registers this device for push notifications and keeps the token
/// registered with the server.
///
/// Flow: `register(api)` is called once the player is signed in and
/// on the map (so the iOS permission prompt appears in a meaningful
/// context, not at cold boot). It requests permission, fetches the
/// FCM token, POSTs it to the server, and re-POSTs on rotation.
///
/// Foreground messages are deliberately ignored — the Phoenix socket
/// already delivers live toasts while the app is open; push exists
/// for the backgrounded/locked-phone case, where the OS displays the
/// notification itself.
class PushService {
  PushService._();

  static final Logger _log = Logger();

  // Keyed by user, not process: the server upserts tokens by token
  // value, so when a different account signs in on this device the
  // token must be re-sent to move it to the new user — otherwise
  // their team's pushes go nowhere.
  static String? _registeredUserId;
  static bool _listening = false;

  static Future<void> register(LandgrabApi api) async {
    final userId = await UserService.getUserId();
    if (userId == null || userId == _registeredUserId) return;
    _registeredUserId = userId;

    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _log.i('push: permission denied; not registering a token');
        return;
      }

      final token = await messaging.getToken();
      if (token != null) {
        await _send(api, token);
      }

      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen((fresh) => _send(api, fresh));
      }
    } catch (e) {
      // Push is an enhancement; never let its failure affect the app.
      _log.w('push: registration failed: $e');
      _registeredUserId = null; // allow a retry on next map entry
    }
  }

  static Future<void> _send(LandgrabApi api, String token) async {
    try {
      await api.registerDeviceToken(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _log.i('push: token registered');
    } catch (e) {
      _log.w('push: token registration failed: $e');
    }
  }
}
