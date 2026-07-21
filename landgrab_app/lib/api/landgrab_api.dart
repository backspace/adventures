import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:landgrab/l10n/player_strings.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/models/notification.dart';
import 'package:landgrab/models/organiser_message.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/models/validator_only_puzzlet.dart';
import 'package:landgrab/services/user_service.dart';

typedef NotificationsResult = ({
  List<LandgrabNotification> notifications,
  int unread,
});

typedef EndgameConfig = ({EndgameZone? endgame, DateTime? announcedAt});

/// Result of an email/password login attempt, kept distinct so the
/// UI can tell "wrong password" apart from "couldn't reach the server".
enum LoginOutcome { success, invalidCredentials, unreachable, failed }

/// Outcome of an email/password account-creation attempt.
///
/// [invalid] carries the server's per-field validation messages
/// (e.g. email already taken, password too short) in [RegisterOutcome.message]
/// so the sign-up form can show exactly what went wrong; [unreachable]
/// and [failed] mirror [LoginOutcome].
enum RegisterStatus { success, invalid, unreachable, failed }

typedef RegisterOutcome = ({RegisterStatus status, String? message});

/// Result of joining a team by its code. [notFound] is the "wrong/expired
/// code" case (server 404), kept distinct so the UI can prompt a re-check
/// rather than showing a generic failure.
enum JoinTeamOutcome { success, notFound, failed }

class LandgrabApi {
  final Dio dio;

  LandgrabApi(this.dio);

  Future<LoginOutcome> login(String email, String password) async {
    try {
      final response = await dio.post(
        '/powapi/session',
        data: {
          'user': {'email': email, 'password': password}
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await UserService.setTokens(
        data['access_token'] as String,
        data['renewal_token'] as String,
      );
      await loadAndStoreMe();
      return LoginOutcome.success;
    } on DioException catch (e) {
      // 401 is the only "wrong email/password" case (see the server's
      // ApiSessionController). No response at all means we never
      // reached the server — a connectivity problem (VPN down, wrong
      // host, offline), NOT bad credentials. Any other response is a
      // genuine server-side failure.
      if (e.response?.statusCode == 401) return LoginOutcome.invalidCredentials;
      if (e.response == null) return LoginOutcome.unreachable;
      return LoginOutcome.failed;
    }
  }

  /// Create a new email/password account via the same Pow-backed API the
  /// web registration form uses (`POST /powapi/registration`). On success
  /// the server returns tokens exactly like [login] and we store them, so
  /// the caller is signed in immediately (no separate login step). The
  /// account starts bare — email/password only — and the profile (team,
  /// accessibility, attending, …) is filled in afterwards via the
  /// `/details` WebView.
  Future<RegisterOutcome> register(String email, String password) async {
    try {
      final response = await dio.post(
        '/powapi/registration',
        // The web form posts `password_confirmation`; the app has a
        // single password field, so we mirror it here to satisfy Pow's
        // confirmation check regardless of how it's configured.
        data: {
          'user': {
            'email': email,
            'password': password,
            'password_confirmation': password,
          }
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await UserService.setTokens(
        data['access_token'] as String,
        data['renewal_token'] as String,
      );
      await loadAndStoreMe();
      return (status: RegisterStatus.success, message: null);
    } on DioException catch (e) {
      // No response at all means we never reached the server (see the
      // note in [login]). Otherwise the server returns a body with
      // per-field validation errors (email taken, password too short);
      // surface those so the user can fix the form.
      if (e.response == null) {
        return (status: RegisterStatus.unreachable, message: null);
      }
      final message = _registrationErrorMessage(e.response?.data);
      if (message != null) {
        return (status: RegisterStatus.invalid, message: message);
      }
      return (status: RegisterStatus.failed, message: null);
    }
  }

  /// Request a password-reset email via the API
  /// (`POST /powapi/reset-password`), mirroring the web PowResetPassword
  /// flow. The server always responds 200 whether or not the email is
  /// registered (no account enumeration), so this returns true unless the
  /// request never reached the server. The actual "choose a new password"
  /// step happens through the emailed link, which opens in the system
  /// browser.
  Future<bool> requestPasswordReset(String email) async {
    try {
      await dio.post(
        '/powapi/reset-password',
        data: {
          'user': {'email': email}
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      return true;
    } on DioException catch (e) {
      // Only a genuine connectivity failure (no response at all) is worth
      // surfacing — see the note in [login]. Any server response means the
      // request was handled (and, for enumeration safety, looks identical
      // whether or not the email exists).
      return e.response != null;
    }
  }

  /// Flatten the server's registration error body
  /// (`{error: {message, errors: {field: [msgs]}}}`) into a readable,
  /// multi-line string like "Email has already been taken". Returns null
  /// if the body has no recognisable error detail.
  String? _registrationErrorMessage(dynamic body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;

    final errors = error['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final lines = <String>[];
      errors.forEach((field, messages) {
        final label = _humaniseField(field.toString());
        if (messages is List) {
          for (final m in messages) {
            lines.add('$label $m');
          }
        } else if (messages is String) {
          lines.add('$label $messages');
        }
      });
      if (lines.isNotEmpty) return lines.join('\n');
    }

    final message = error['message'];
    return message is String ? message : null;
  }

  String _humaniseField(String field) {
    if (field.isEmpty) return field;
    final spaced = field.replaceAll('_', ' ');
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  // Custom URI scheme the app registered on iOS (CFBundleURLTypes) and
  // Android (intent-filter on flutter_web_auth_2 CallbackActivity). The
  // server 302s Google's callback to this scheme so ASWebAuthentication-
  // Session / Custom Tabs can hand control back to us with the code.
  static const _oauthCallbackScheme = 'ca.chromatin.poles';

  /// Native iOS Sign in with Apple flow. Given the identity token
  /// (JWT signed by Apple) and the optional user credential returned
  /// by `SignInWithApple.getAppleIDCredential`, POSTs to the backend
  /// which verifies the JWT and upserts the user. Returns true on
  /// success and stores tokens exactly like [login].
  ///
  /// [identityToken] comes from `AuthorizationCredentialAppleID.identityToken`.
  /// [email] / [givenName] / [familyName] are only returned by Apple
  /// on the FIRST sign-in with the app — pass whatever the credential
  /// includes; the backend uses them to seed a new account.
  Future<bool> loginWithAppleNative({
    required String identityToken,
    String? email,
    String? givenName,
    String? familyName,
  }) async {
    try {
      final response = await dio.post(
        '/powapi/auth/apple/native_callback',
        data: {
          'identity_token': identityToken,
          if (email != null || givenName != null || familyName != null)
            'user': {
              if (email != null) 'email': email,
              if (givenName != null) 'given_name': givenName,
              if (familyName != null) 'family_name': familyName,
            },
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await UserService.setTokens(
        data['access_token'] as String,
        data['renewal_token'] as String,
      );
      await loadAndStoreMe();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs the "sign in with `<provider>`" flow via a system-provided
  /// browser (Google explicitly blocks embedded WebViews). Returns true
  /// on success and stores the resulting session tokens exactly like
  /// [login]. Errors — cancelled tab, network failure, server rejects
  /// the token exchange — are swallowed to false so the caller can
  /// surface a single "sign-in failed" message.
  Future<bool> loginWithOAuth(String provider) async {
    try {
      // 1) Ask the server for the Google auth URL and the session
      //    params it wants back on the callback POST. `client=mobile`
      //    makes the server select the `mobile_bounce` redirect URI so
      //    the redirect chain lands back in the app.
      final newResp = await dio.get(
        '/powapi/auth/$provider/new',
        queryParameters: const {'client': 'mobile'},
      );
      final data = newResp.data['data'] as Map<String, dynamic>;
      final authUrl = data['url'] as String;
      final sessionParams = data['session_params'];

      // 2) Open the system browser, wait for a redirect to our scheme.
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: _oauthCallbackScheme,
      );

      // 3) Extract the code (and state) from the intercepted URL and
      //    hand them back to the server for the token exchange.
      final callbackUri = Uri.parse(callbackUrl);
      if (callbackUri.queryParameters['error'] != null) return false;
      final code = callbackUri.queryParameters['code'];
      final state = callbackUri.queryParameters['state'];
      if (code == null) return false;

      final callbackResp = await dio.post(
        '/powapi/auth/$provider/callback',
        queryParameters: const {'client': 'mobile'},
        data: {
          'code': code,
          if (state != null) 'state': state,
          'session_params': sessionParams,
        },
      );

      final tokens = callbackResp.data['data'] as Map<String, dynamic>;
      await UserService.setTokens(
        tokens['access_token'] as String,
        tokens['renewal_token'] as String,
      );
      await loadAndStoreMe();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Register (or refresh) this device's push token so the server
  /// can send notifications when the app is backgrounded.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await dio.post('/powapi/device-tokens', data: {
      'token': token,
      'platform': platform,
    });
  }

  /// Fire-and-forget boot ping so the server can record that this
  /// user has opened the app. Called from `_Boot` after we've
  /// confirmed the user is signed in. Any error is swallowed —
  /// telemetry must never gate the login → home transition.
  Future<void> pingAppOpened() async {
    try {
      await dio.post('/powapi/telemetry/app_opened');
    } catch (_) {
      // Silent — see doc.
    }
  }

  Future<void> loadAndStoreMe() async {
    final response = await dio.get('/landgrab/me');
    final user = response.data['user'] as Map<String, dynamic>;
    final team = response.data['team'] as Map<String, dynamic>?;
    final roles =
        (user['roles'] as List?)?.map((r) => r as String).toList() ?? const [];
    await UserService.setUserData(
      user['id'] as String,
      user['email'] as String,
      name: user['name'] as String?,
      teamId: team?['id'] as String?,
      teamName: team?['name'] as String?,
      teamColorIndex: team?['color_index'] as int?,
      roles: roles,
    );
    // Auto-remember this account for the dev account-switcher (no-op in
    // normal use; the switcher UI is behind the env-switch unlock).
    await UserService.rememberCurrentAccount();
    // Piggy-back the boot-telemetry ping on the "user data loaded"
    // moment, since every login path ends here. The `_Boot` path
    // (already-logged-in restart) pings directly — this covers the
    // fresh-login case without instrumenting each login callsite.
    pingAppOpened();
  }

  /// Join a team by its code (scanned from a team card's QR, or typed).
  /// On success the server sets our team, and we refresh `/me` so the
  /// stored team id/name reflect it immediately.
  Future<JoinTeamOutcome> joinTeam(String code) async {
    try {
      await dio.post('/landgrab/team/join', data: {'code': code.trim()});
      await loadAndStoreMe();
      return JoinTeamOutcome.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return JoinTeamOutcome.notFound;
      return JoinTeamOutcome.failed;
    }
  }

  Future<LandgrabEvent> getEvent() async {
    final response = await dio.get('/landgrab/event');
    return LandgrabEvent.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Pole>> listPoles() async {
    final response = await dio.get('/landgrab/poles');
    final list = response.data['poles'] as List;
    return list
        .map((p) => Pole.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ScanOutcome> scan(String barcode, {List<String> exclude = const []}) async {
    try {
      // `exclude` carries puzzlets the team declined this session ("Not this
      // one" on an accessibility conflict), so the server serves the next.
      final response = await dio.get(
        '/landgrab/poles/$barcode',
        queryParameters:
            exclude.isEmpty ? null : {'exclude': exclude.join(',')},
      );
      return ScanFound(
          ScanResult.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const ScanUnknownBarcode();
      final code = _errorCode(e);
      if (code == 'not_started') return const ScanNotStarted();
      final poleJson = _poleJson(e);
      if (code == 'already_owner' && poleJson != null) {
        return ScanAlreadyOwner(Pole.fromJson(poleJson));
      }
      if (code == 'team_locked_out' && poleJson != null) {
        return ScanTeamLockedOut(Pole.fromJson(poleJson));
      }
      if (code == 'own_creation' && poleJson != null) {
        return ScanOwnCreation(Pole.fromJson(poleJson));
      }
      if (code == 'outside_zone' && poleJson != null) {
        return ScanOutsideZone(Pole.fromJson(poleJson));
      }
      if (code == 'at_capacity') {
        final active = (e.response?.data['active_puzzlets'] as List?)
                ?.map((p) => ScanResult.fromJson(p as Map<String, dynamic>))
                .toList(growable: false) ??
            const [];
        return ScanAtCapacity(active);
      }
      rethrow;
    }
  }

  /// The team's active puzzlets — what's shown as "in progress" and
  /// resumed into without a rescan.
  Future<List<ScanResult>> listActivePuzzlets() async {
    final response = await dio.get('/landgrab/active-puzzlets');
    return (response.data['active_puzzlets'] as List)
        .map((p) => ScanResult.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Assign the pole's next puzzlet without a rescan ("try the next
  /// one" after a rival captures yours). Returns the resumed payload,
  /// or throws on at_capacity / locked-out / no-puzzlet.
  Future<ScanResult> assignActivePuzzlet(String poleId) async {
    final response =
        await dio.post('/landgrab/active-puzzlets', data: {'pole_id': poleId});
    return ScanResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> abandonActivePuzzlet(String puzzletId) async {
    await dio.delete('/landgrab/active-puzzlets/$puzzletId');
  }

  /// Claim a prohibitive stake without solving (accommodation). Returns the
  /// updated pole on success. Throws on failure (the caller surfaces it) — the
  /// server verifies the stake really is prohibitive for the team, so this can
  /// come back 409 `not_prohibitive` if the map was stale.
  Future<Pole> claimWithoutSolving(String barcode) async {
    final response =
        await dio.post('/landgrab/poles/$barcode/accommodation');
    return Pole.fromJson(response.data['pole'] as Map<String, dynamic>);
  }

  Future<AttemptOutcome> submitAnswer(String puzzletId, String answer) async {
    try {
      final response = await dio.post(
        '/landgrab/puzzlets/$puzzletId/attempts',
        data: {'answer': answer},
      );
      final body = response.data as Map<String, dynamic>;
      if (body['correct'] == true) {
        return AttemptCorrect(
          captureTeamId: body['pole']['current_owner_team_id'] as String,
          poleLocked: body['pole']['locked'] as bool,
          captureColorIndex: body['pole']['current_owner_color_index'] as int?,
        );
      }
      return AttemptIncorrect(
        attemptsRemaining: body['attempts_remaining'] as int,
        previousWrongAnswers: (body['previous_wrong_answers'] as List?)
                ?.map((e) => e as String)
                .toList(growable: false) ??
            const [],
      );
    } on DioException catch (e) {
      final code = _errorCode(e);
      if (e.response?.statusCode == 423 || code == 'locked_out') {
        return const AttemptLockedOut();
      }
      if (code == 'already_owner') {
        return const AttemptAlreadyOwner();
      }
      if (code == 'game_over') {
        return const AttemptGameOver();
      }
      if (code == 'not_active') {
        return const AttemptFailed(PuzzletStrings.notActive);
      }
      if (code == 'own_creation') {
        return const AttemptFailed(PuzzletStrings.ownCreation);
      }
      if (code == 'withdrawn') {
        return const AttemptWithdrawn();
      }
      if (e.response?.statusCode == 409 || code == 'already_captured') {
        return const AttemptAlreadyCaptured();
      }
      // Anything else becomes a displayable failure rather than a
      // thrown exception — a rethrow here used to escape the puzzlet
      // screen's submit handler and leave it spinning forever.
      return AttemptFailed(attemptFailureMessage(e));
    }
  }

  /// Human-readable message for an unmodelled attempt failure.
  /// Prefers the server's error detail (e.g. "User is not on a
  /// team.") and falls back to a generic network message when the
  /// request never got a response.
  String attemptFailureMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['detail'] is String) {
        return error['detail'] as String;
      }
    }
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      return PuzzletStrings.submissionFailedHttp(statusCode);
    }
    return PuzzletStrings.submissionFailedNetwork;
  }

  String? _errorCode(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final error = data['error'];
    if (error is! Map) return null;
    final code = error['code'];
    return code is String ? code : null;
  }

  Map<String, dynamic>? _poleJson(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final pole = data['pole'];
    return pole is Map<String, dynamic> ? pole : null;
  }

  Future<MyDrafts> listMyDrafts() async {
    final response = await dio.get('/landgrab/drafts/mine');
    return MyDrafts.fromJson(response.data as Map<String, dynamic>);
  }

  /// Ask the server for a short-lived signed URL that a WebView can
  /// hit to transition our API session into a browser cookie session
  /// on the site (so the app can host `/details` and other web pages
  /// without asking the user to sign in a second time). Consumers
  /// should open the URL immediately — server TTL is only 60s.
  Future<String> mintDetailsExchangeUrl() async {
    final response = await dio.post('/powapi/session/exchange');
    final data = response.data['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  /// Fetch every puzzlet + pole (regardless of author) within an
  /// approximate radius of the given point. Backs the mini-map on the
  /// pole-capture flow so the author sees which nearby puzzlets need a
  /// pole and where existing poles already sit.
  Future<MyDrafts> getNearbyDrafts({
    required double latitude,
    required double longitude,
    double? radiusM,
  }) async {
    final response = await dio.get(
      '/landgrab/drafts/nearby',
      queryParameters: {
        'lat': latitude,
        'lng': longitude,
        if (radiusM != null) 'radius_m': radiusM,
      },
    );
    return MyDrafts.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPole> createDraftPole({
    required String barcode,
    required double latitude,
    required double longitude,
    String? label,
    String? notes,
    double? accuracyM,
    double? manualOffsetM,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
  }) async {
    final response = await dio.post('/landgrab/drafts/poles', data: {
      'barcode': barcode,
      'latitude': latitude,
      'longitude': longitude,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (manualOffsetM != null) 'manual_offset_m': manualOffsetM,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> createDraftPuzzlet({
    required String instructions,
    required String answer,
    required int difficulty,
    AnswerType? answerType,
    double? latitude,
    double? longitude,
    double? accuracyM,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? regionId,
    String? warning,
    bool? validatorOnly,
  }) async {
    final response = await dio.post('/landgrab/drafts/puzzlets', data: {
      'instructions': instructions,
      'answer': answer,
      'difficulty': difficulty,
      if (answerType != null) 'answer_type': answerTypeToString(answerType),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (regionId != null) 'region_id': regionId,
      if (warning != null) 'warning': warning,
      if (validatorOnly != null) 'validator_only': validatorOnly,
    });
    return DraftPuzzlet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPole> updateDraftPole(
    String id, {
    String? barcode,
    String? label,
    String? notes,
    double? latitude,
    double? longitude,
    double? accuracyM,
    double? manualOffsetM,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
  }) async {
    final response = await dio.patch('/landgrab/drafts/poles/$id', data: {
      if (barcode != null) 'barcode': barcode,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (manualOffsetM != null) 'manual_offset_m': manualOffsetM,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> updateDraftPuzzlet(
    String id, {
    String? instructions,
    String? answer,
    AnswerType? answerType,
    int? difficulty,
    double? latitude,
    double? longitude,
    double? accuracyM,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? regionId,
    bool clearRegion = false,
    String? poleId,
    bool clearPole = false,
    String? warning,
    bool? validatorOnly,
  }) async {
    final response = await dio.patch('/landgrab/drafts/puzzlets/$id', data: {
      if (instructions != null) 'instructions': instructions,
      if (answer != null) 'answer': answer,
      if (answerType != null) 'answer_type': answerTypeToString(answerType),
      if (difficulty != null) 'difficulty': difficulty,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (clearRegion)
        'region_id': null
      else if (regionId != null)
        'region_id': regionId,
      if (clearPole) 'pole_id': null else if (poleId != null) 'pole_id': poleId,
      if (warning != null) 'warning': warning,
      if (validatorOnly != null) 'validator_only': validatorOnly,
    });
    return DraftPuzzlet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDraftPole(String id) =>
      dio.delete('/landgrab/drafts/poles/$id');

  Future<void> deleteDraftPuzzlet(String id) =>
      dio.delete('/landgrab/drafts/puzzlets/$id');

  /// Withdraw a puzzlet from live play (supervisor). Teams working it are
  /// notified and offered the pole's next puzzlet — the same flow a rival
  /// capture triggers. See the server's `withdraw_puzzlet`.
  Future<void> withdrawPuzzlet(String puzzletId) =>
      dio.post('/landgrab/supervision/puzzlets/$puzzletId/withdraw');

  Future<List<Region>> searchRegions({String? query}) async {
    final response = await dio.get(
      '/landgrab/regions',
      queryParameters: query == null || query.isEmpty ? null : {'q': query},
    );
    final list = (response.data as Map<String, dynamic>)['regions'] as List;
    return list
        .map((r) => Region.fromJson(r as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Region> getRegion(String id) async {
    final response = await dio.get('/landgrab/regions/$id');
    return Region.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Region> createRegion({
    required String name,
    String? parentRegionId,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? entryInstructions,
  }) async {
    final response = await dio.post('/landgrab/regions', data: {
      'name': name,
      if (parentRegionId != null) 'parent_region_id': parentRegionId,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (entryInstructions != null) 'entry_instructions': entryInstructions,
    });
    return Region.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Region> updateRegion(
    String id, {
    String? name,
    String? parentRegionId,
    bool clearParent = false,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? entryInstructions,
  }) async {
    final response = await dio.patch('/landgrab/regions/$id', data: {
      if (name != null) 'name': name,
      if (clearParent)
        'parent_region_id': null
      else if (parentRegionId != null)
        'parent_region_id': parentRegionId,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (entryInstructions != null) 'entry_instructions': entryInstructions,
    });
    return Region.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Bathrooms ──────────────────────────────────────────────

  /// Validator-only puzzlets for display on the gameplay map. Server
  /// gates this to users with the validator role; a 403 here is a
  /// meaningful "you're not a validator, don't show the layer".
  Future<List<ValidatorOnlyPuzzlet>> listValidatorOnlyPuzzlets() async {
    final response =
        await dio.get('/landgrab/validation/validator-only-puzzlets');
    final list = (response.data as Map<String, dynamic>)['puzzlets'] as List;
    return list
        .map((p) => ValidatorOnlyPuzzlet.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Bathroom>> listBathrooms() async {
    final response = await dio.get('/landgrab/bathrooms');
    final list = (response.data as Map<String, dynamic>)['bathrooms'] as List;
    return list
        .map((b) => Bathroom.fromJson(b as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The team's notification history, newest first, plus how many
  /// are unread (drives the bell badge).
  Future<NotificationsResult> listNotifications() async {
    final response = await dio.get('/landgrab/notifications');
    final data = response.data as Map<String, dynamic>;
    final list = data['notifications'] as List;
    return (
      notifications: list
          .map((n) => LandgrabNotification.fromJson(n as Map<String, dynamic>))
          .toList(growable: false),
      unread: (data['unread'] as num?)?.toInt() ?? 0,
    );
  }

  /// Marks the whole team's notifications read (shared badge — one
  /// member reading clears it for both).
  Future<void> markNotificationsRead() async {
    await dio.post('/landgrab/notifications/read');
  }

  /// Toggle one notification's read state (swipe in the history).
  Future<void> setNotificationRead(String id, bool read) async {
    await dio.post('/landgrab/notifications/$id/${read ? 'read' : 'unread'}');
  }

  Future<List<Bathroom>> listMyBathrooms() async {
    final response = await dio.get('/landgrab/bathrooms/mine');
    final list = (response.data as Map<String, dynamic>)['bathrooms'] as List;
    return list
        .map((b) => Bathroom.fromJson(b as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Bathroom> createBathroom({
    String? name,
    required double latitude,
    required double longitude,
    double? accuracyM,
    String? notes,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? entryInstructions,
    String? regionId,
  }) async {
    final response = await dio.post('/landgrab/bathrooms', data: {
      if (name != null) 'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (notes != null) 'notes': notes,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (entryInstructions != null) 'entry_instructions': entryInstructions,
      if (regionId != null) 'region_id': regionId,
    });
    return Bathroom.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Bathroom> updateBathroom(
    String id, {
    String? name,
    double? latitude,
    double? longitude,
    double? accuracyM,
    String? notes,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? entryInstructions,
    String? regionId,
    bool clearRegion = false,
  }) async {
    final response = await dio.patch('/landgrab/bathrooms/$id', data: {
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (notes != null) 'notes': notes,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (entryInstructions != null) 'entry_instructions': entryInstructions,
      if (clearRegion)
        'region_id': null
      else if (regionId != null)
        'region_id': regionId,
    });
    return Bathroom.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteBathroom(String id) =>
      dio.delete('/landgrab/bathrooms/$id');

  Future<String> uploadPoleAttachment({
    required String poleId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await dio.post(
      '/landgrab/drafts/poles/$poleId/attachments',
      data: form,
    );
    return (response.data as Map<String, dynamic>)['id'] as String;
  }

  Future<String> uploadPuzzletAttachment({
    required String puzzletId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final form = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(contentType),
      ),
    });
    final response = await dio.post(
      '/landgrab/drafts/puzzlets/$puzzletId/attachments',
      data: form,
    );
    return (response.data as Map<String, dynamic>)['id'] as String;
  }

  Future<void> deleteAttachment(String id) =>
      dio.delete('/landgrab/drafts/attachments/$id');

  String attachmentUrl(String id) =>
      '${dio.options.baseUrl}/landgrab/attachments/$id';

  String attachmentThumbUrl(String id) =>
      '${dio.options.baseUrl}/landgrab/attachments/$id/thumb';

  // ────────── Validator surface ──────────

  Future<MyValidations> listMyValidations() async {
    final response = await dio.get('/landgrab/validation/mine');
    return MyValidations.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoleValidationModel> transitionPoleValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/validation/pole-validations/$id',
      data: {'status': status},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submit the validator's pole form in one call: the diffed fields as
  /// [suggestions] (each `{'field': ..., 'suggested_value': ...}`), an
  /// optional note to the supervisor, and whether the pole was scan-
  /// verified on-site. An empty [suggestions] list is a clean endorsement.
  Future<PoleValidationModel> submitPoleValidation(
    String id, {
    required bool physicallyVerified,
    String? overallNotes,
    List<Map<String, dynamic>> suggestions = const [],
  }) async {
    final response = await dio.post(
      '/landgrab/validation/pole-validations/$id/submit',
      data: {
        'physically_verified': physicallyVerified,
        if (overallNotes != null && overallNotes.isNotEmpty)
          'overall_notes': overallNotes,
        'suggestions': suggestions,
      },
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Report that the pole couldn't be found on-site.
  Future<PoleValidationModel> markPoleUnfindable(
    String id, {
    String? overallNotes,
  }) async {
    final response = await dio.post(
      '/landgrab/validation/pole-validations/$id/unfindable',
      data: {
        if (overallNotes != null && overallNotes.isNotEmpty)
          'overall_notes': overallNotes,
      },
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Resolve a scanned barcode against the validator's assignments,
  /// relative to the pole they tapped ([tappedValidationId]).
  Future<ScanResolution> resolvePoleScan({
    required String barcode,
    required String tappedValidationId,
  }) async {
    final response = await dio.get(
      '/landgrab/validation/scan',
      queryParameters: {'barcode': barcode, 'validation_id': tappedValidationId},
    );
    return ScanResolution.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> transitionPuzzletValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/validation/puzzlet-validations/$id',
      data: {'status': status},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Submit the validator's puzzlet review in one call: [suggestions]
  /// (each `{'field': ..., 'suggested_value': ...}`) plus an optional
  /// note. An empty list endorses the puzzlet as-is (submitted, no
  /// suggestions) — what "previewed it and it's fine" sends.
  Future<PuzzletValidationModel> submitPuzzletValidation(
    String id, {
    String? overallNotes,
    List<Map<String, dynamic>> suggestions = const [],
  }) async {
    final response = await dio.post(
      '/landgrab/validation/puzzlet-validations/$id/submit',
      data: {
        if (overallNotes != null && overallNotes.isNotEmpty)
          'overall_notes': overallNotes,
        'suggestions': suggestions,
      },
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> createPoleComment(
    String validationId, {
    required String field,
    String? comment,
    String? suggestedValue,
  }) async {
    final response = await dio.post(
      '/landgrab/validation/pole-validations/$validationId/comments',
      data: {
        'field': field,
        if (comment != null) 'comment': comment,
        if (suggestedValue != null) 'suggested_value': suggestedValue,
      },
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> createPuzzletComment(
    String validationId, {
    required String field,
    String? comment,
    String? suggestedValue,
  }) async {
    final response = await dio.post(
      '/landgrab/validation/puzzlet-validations/$validationId/comments',
      data: {
        'field': field,
        if (comment != null) 'comment': comment,
        if (suggestedValue != null) 'suggested_value': suggestedValue,
      },
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePoleComment(String id) =>
      dio.delete('/landgrab/validation/pole-comments/$id');

  Future<void> deletePuzzletComment(String id) =>
      dio.delete('/landgrab/validation/puzzlet-comments/$id');

  // ────────── Supervisor surface ──────────

  Future<EndgameConfig> getEndgameConfig() async {
    final response = await dio.get('/landgrab/supervision/endgame');
    final data = response.data as Map<String, dynamic>;
    return (
      endgame: EndgameZone.fromJson(data['endgame'] as Map<String, dynamic>?),
      announcedAt: data['announced_at'] == null
          ? null
          : DateTime.tryParse('${data['announced_at']}Z'),
    );
  }

  /// Full-replace: pass a zone to (re)configure the boundary, or
  /// null to clear it. The server broadcasts `event_updated` so all
  /// player maps re-sync immediately.
  Future<EndgameConfig> updateEndgameConfig(EndgameZone? zone) async {
    final response = await dio.put('/landgrab/supervision/endgame', data: {
      if (zone != null) ...{
        'latitude': zone.latitude,
        'longitude': zone.longitude,
        'starts_at': zone.startsAt.toUtc().toIso8601String(),
        'ends_at': zone.endsAt.toUtc().toIso8601String(),
        'initial_radius_m': zone.initialRadiusM,
        'final_radius_m': zone.finalRadiusM,
      },
    });
    final data = response.data as Map<String, dynamic>;
    return (
      endgame: EndgameZone.fromJson(data['endgame'] as Map<String, dynamic>?),
      announcedAt: data['announced_at'] == null
          ? null
          : DateTime.tryParse('${data['announced_at']}Z'),
    );
  }

  /// Whether the relief valve (re-openable stakes, per-team consumption) is on.
  Future<bool> getReliefActive() async {
    final response = await dio.get('/landgrab/supervision/relief');
    return response.data['active'] == true;
  }

  /// Turn the relief valve on or off. Returns the resulting state.
  Future<bool> setReliefActive(bool on) async {
    final response =
        await dio.put('/landgrab/supervision/relief', data: {'on': on});
    return response.data['active'] == true;
  }

  Future<List<OrganiserMessage>> listOrganiserMessages() async {
    final response = await dio.get('/landgrab/supervision/messages');
    return (response.data['messages'] as List)
        .map((m) => OrganiserMessage.fromJson(m as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Creates a message; with [sendNow] it fans out to all teams
  /// immediately, otherwise it's saved as a draft for later sending.
  Future<OrganiserMessage> createOrganiserMessage({
    required String body,
    required String senderName,
    bool sendNow = false,
  }) async {
    final response = await dio.post('/landgrab/supervision/messages', data: {
      'body': body,
      'sender_name': senderName,
      if (sendNow) 'send': true,
    });
    return OrganiserMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OrganiserMessage> sendOrganiserMessage(String id) async {
    final response = await dio.post('/landgrab/supervision/messages/$id/send');
    return OrganiserMessage.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DashboardCounts> supervisorDashboard() async {
    final response = await dio.get('/landgrab/supervision/dashboard');
    return DashboardCounts.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bulk-assign every listed pole and puzzlet to one validator (the
  /// draw-an-area flow). Items that can't take the assignment are
  /// skipped server-side and counted.
  Future<({int assigned, int skipped})> bulkAssignValidations({
    required String validatorId,
    required List<String> poleIds,
    required List<String> puzzletIds,
  }) async {
    final response = await dio.post('/landgrab/supervision/assignments', data: {
      'validator_id': validatorId,
      'pole_ids': poleIds,
      'puzzlet_ids': puzzletIds,
    });
    final data = response.data as Map<String, dynamic>;
    return (
      assigned: (data['assigned'] as num).toInt(),
      skipped: (data['skipped'] as num).toInt(),
    );
  }

  /// Bulk-reassign a validator's open validations. Pass [toValidatorId] to
  /// hand them to another validator, or null to return them to the pool
  /// (unassign). Returns how many moved vs. were skipped (unmovable).
  Future<({int moved, int skipped})> bulkReassignValidations({
    required List<String> poleValidationIds,
    required List<String> puzzletValidationIds,
    String? toValidatorId,
  }) async {
    final response =
        await dio.post('/landgrab/supervision/reassignments', data: {
      'pole_validation_ids': poleValidationIds,
      'puzzlet_validation_ids': puzzletValidationIds,
      if (toValidatorId != null) 'to_validator_id': toValidatorId,
    });
    final data = response.data as Map<String, dynamic>;
    return (
      moved: (data['moved'] as num).toInt(),
      skipped: (data['skipped'] as num).toInt(),
    );
  }

  /// Bulk-accept the given (clean, submitted) validations. The server
  /// accepts the submitted ones and skips anything not acceptable, returning
  /// how many were accepted vs. skipped.
  Future<({int accepted, int skipped})> bulkAcceptValidations({
    required List<String> poleValidationIds,
    required List<String> puzzletValidationIds,
  }) async {
    final response =
        await dio.post('/landgrab/supervision/acceptances', data: {
      'pole_validation_ids': poleValidationIds,
      'puzzlet_validation_ids': puzzletValidationIds,
    });
    final data = response.data as Map<String, dynamic>;
    return (
      accepted: (data['accepted'] as num).toInt(),
      skipped: (data['skipped'] as num).toInt(),
    );
  }

  Future<List<ValidatorUser>> listValidators({String? excludeUserId}) async {
    final response = await dio.get('/landgrab/supervision/validators',
        queryParameters: {
          if (excludeUserId != null) 'exclude_user_id': excludeUserId
        });
    final list = response.data['validators'] as List;
    return list
        .map((e) => ValidatorUser.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<DraftPole>> supervisionListPoles({String? status}) async {
    final response = await dio.get('/landgrab/supervision/poles',
        queryParameters: {if (status != null) 'status': status});
    return (response.data['poles'] as List)
        .map((e) => DraftPole.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<DraftPuzzlet>> supervisionListPuzzlets({String? status}) async {
    final response = await dio.get('/landgrab/supervision/puzzlets',
        queryParameters: {if (status != null) 'status': status});
    return (response.data['puzzlets'] as List)
        .map((e) => DraftPuzzlet.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PoleValidationModel>> listPoleValidations(String poleId) async {
    final response =
        await dio.get('/landgrab/supervision/poles/$poleId/validations');
    return ((response.data['validations'] as List?) ?? const [])
        .map((e) => PoleValidationModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PuzzletValidationModel>> listPuzzletValidations(
      String puzzletId) async {
    final response =
        await dio.get('/landgrab/supervision/puzzlets/$puzzletId/validations');
    return ((response.data['validations'] as List?) ?? const [])
        .map((e) => PuzzletValidationModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PoleValidationModel> assignPoleValidation(
      String poleId, String validatorId) async {
    final response = await dio.post(
      '/landgrab/supervision/poles/$poleId/validations',
      data: {'validator_id': validatorId},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> assignPuzzletValidation(
      String puzzletId, String validatorId) async {
    final response = await dio.post(
      '/landgrab/supervision/puzzlets/$puzzletId/validations',
      data: {'validator_id': validatorId},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Swap the validator on an in-flight pole validation. Throws a
  /// DioException with 409 if the validation has already been finalized.
  Future<PoleValidationModel> reassignPoleValidation(
      String validationId, String validatorId) async {
    final response = await dio.patch(
      '/landgrab/supervision/pole-validations/$validationId/validator',
      data: {'validator_id': validatorId},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> reassignPuzzletValidation(
      String validationId, String validatorId) async {
    final response = await dio.patch(
      '/landgrab/supervision/puzzlet-validations/$validationId/validator',
      data: {'validator_id': validatorId},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// Tear down a fresh assignment (the supervisor's "undo"). Backend
  /// refuses with 409 if the validation has progressed past the initial
  /// assigned state.
  Future<void> unassignPoleValidation(String validationId) async {
    await dio.delete('/landgrab/supervision/pole-validations/$validationId');
  }

  Future<void> unassignPuzzletValidation(String validationId) async {
    await dio.delete('/landgrab/supervision/puzzlet-validations/$validationId');
  }

  Future<PoleValidationModel> supervisorTransitionPoleValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/supervision/pole-validations/$id',
      data: {'status': status},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> supervisorTransitionPuzzletValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/supervision/puzzlet-validations/$id',
      data: {'status': status},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> decidePoleComment(String id, String status) async {
    final response = await dio.patch(
      '/landgrab/supervision/pole-comments/$id',
      data: {'status': status},
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> decidePuzzletComment(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/supervision/puzzlet-comments/$id',
      data: {'status': status},
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPole> supervisorEditPole(
    String id, {
    String? barcode,
    String? label,
    String? notes,
    double? latitude,
    double? longitude,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
  }) async {
    final response = await dio.patch('/landgrab/supervision/poles/$id', data: {
      if (barcode != null) 'barcode': barcode,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> supervisorEditPuzzlet(
    String id, {
    String? instructions,
    String? answer,
    AnswerType? answerType,
    int? difficulty,
    List<String>? accessibilityTags,
    String? accessibilityNotes,
    String? warning,
  }) async {
    final response =
        await dio.patch('/landgrab/supervision/puzzlets/$id', data: {
      if (instructions != null) 'instructions': instructions,
      if (answer != null) 'answer': answer,
      if (answerType != null) 'answer_type': answerTypeToString(answerType),
      if (difficulty != null) 'difficulty': difficulty,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (warning != null) 'warning': warning,
    });
    return DraftPuzzlet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await dio.delete('/powapi/session');
    } catch (_) {
      // Ignore — we're clearing local state regardless.
    }
    await UserService.clearUserData();
  }
}
