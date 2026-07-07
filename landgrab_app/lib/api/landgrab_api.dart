import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:landgrab/models/bathroom.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/pole.dart';
import 'package:landgrab/models/landgrab_event.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/models/test_session.dart';
import 'package:landgrab/models/validation.dart';
import 'package:landgrab/services/user_service.dart';

class LandgrabApi {
  final Dio dio;

  LandgrabApi(this.dio);

  Future<bool> login(String email, String password) async {
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
      return true;
    } on DioException {
      return false;
    }
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
    final roles = (user['roles'] as List?)?.map((r) => r as String).toList() ?? const [];
    await UserService.setUserData(
      user['id'] as String,
      user['email'] as String,
      name: user['name'] as String?,
      teamId: team?['id'] as String?,
      teamName: team?['name'] as String?,
      roles: roles,
    );
    // Piggy-back the boot-telemetry ping on the "user data loaded"
    // moment, since every login path ends here. The `_Boot` path
    // (already-logged-in restart) pings directly — this covers the
    // fresh-login case without instrumenting each login callsite.
    pingAppOpened();
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

  Future<ScanOutcome> scan(String barcode) async {
    try {
      final response = await dio.get('/landgrab/poles/$barcode');
      return ScanFound(ScanResult.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const ScanUnknownBarcode();
      final code = _errorCode(e);
      final poleJson = _poleJson(e);
      if (code == 'already_owner' && poleJson != null) {
        return ScanAlreadyOwner(Pole.fromJson(poleJson));
      }
      if (code == 'team_locked_out' && poleJson != null) {
        return ScanTeamLockedOut(Pole.fromJson(poleJson));
      }
      rethrow;
    }
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
      if (e.response?.statusCode == 409 || code == 'already_captured') {
        return const AttemptAlreadyCaptured();
      }
      rethrow;
    }
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
    String? warning,
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
      if (clearRegion) 'region_id': null
      else if (regionId != null) 'region_id': regionId,
      if (warning != null) 'warning': warning,
    });
    return DraftPuzzlet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDraftPole(String id) =>
      dio.delete('/landgrab/drafts/poles/$id');

  Future<void> deleteDraftPuzzlet(String id) =>
      dio.delete('/landgrab/drafts/puzzlets/$id');

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
      if (clearParent) 'parent_region_id': null
      else if (parentRegionId != null) 'parent_region_id': parentRegionId,
      if (accessibilityTags != null) 'accessibility_tags': accessibilityTags,
      if (accessibilityNotes != null) 'accessibility_notes': accessibilityNotes,
      if (entryInstructions != null) 'entry_instructions': entryInstructions,
    });
    return Region.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Bathrooms ──────────────────────────────────────────────

  Future<List<Bathroom>> listBathrooms() async {
    final response = await dio.get('/landgrab/bathrooms');
    final list = (response.data as Map<String, dynamic>)['bathrooms'] as List;
    return list
        .map((b) => Bathroom.fromJson(b as Map<String, dynamic>))
        .toList(growable: false);
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
      if (clearRegion) 'region_id': null
      else if (regionId != null) 'region_id': regionId,
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

  Future<PuzzletValidationModel> transitionPuzzletValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/landgrab/validation/puzzlet-validations/$id',
      data: {'status': status},
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

  Future<DashboardCounts> supervisorDashboard() async {
    final response = await dio.get('/landgrab/supervision/dashboard');
    return DashboardCounts.fromJson(response.data as Map<String, dynamic>);
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
    final response = await dio.get('/landgrab/supervision/poles/$poleId/validations');
    return ((response.data['validations'] as List?) ?? const [])
        .map((e) => PoleValidationModel.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<PuzzletValidationModel>> listPuzzletValidations(String puzzletId) async {
    final response = await dio.get('/landgrab/supervision/puzzlets/$puzzletId/validations');
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
    final response = await dio.patch('/landgrab/supervision/puzzlets/$id', data: {
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

  // ─── Test play sessions ─────────────────────────────────────────────

  Future<TestSession> createTestSession({String? name}) async {
    final response = await dio.post(
      '/landgrab/test-play/sessions',
      data: {if (name != null) 'name': name},
    );
    return TestSession.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TestSession>> listTestSessions() async {
    final response = await dio.get('/landgrab/test-play/sessions');
    final list = response.data['sessions'] as List;
    return list
        .map((e) => TestSession.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<TestSession> endTestSession(String id) async {
    final response = await dio.post('/landgrab/test-play/sessions/$id/end');
    return TestSession.fromJson(response.data as Map<String, dynamic>);
  }
}

/// LandgrabApi subclass that redirects gameplay calls (listPoles, scan,
/// submitAnswer) to the scoped test-play endpoints. Other methods inherit
/// from the parent unchanged.
class TestPlayLandgrabApi extends LandgrabApi {
  final String sessionId;

  TestPlayLandgrabApi(super.dio, this.sessionId);

  @override
  Future<List<Pole>> listPoles() async {
    final response =
        await dio.get('/landgrab/test-play/sessions/$sessionId/poles');
    final list = response.data['poles'] as List;
    return list
        .map((p) => Pole.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<ScanOutcome> scan(String barcode) async {
    try {
      final response = await dio.get(
        '/landgrab/test-play/sessions/$sessionId/poles/$barcode',
      );
      return ScanFound(ScanResult.fromJson(response.data as Map<String, dynamic>));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const ScanUnknownBarcode();
      rethrow;
    }
  }

  @override
  Future<AttemptOutcome> submitAnswer(String puzzletId, String answer) async {
    try {
      final response = await dio.post(
        '/landgrab/test-play/sessions/$sessionId/puzzlets/$puzzletId/attempts',
        data: {'answer': answer},
      );
      final body = response.data as Map<String, dynamic>;
      if (body['correct'] == true) {
        return AttemptCorrect(
          captureTeamId: body['pole']?['current_owner_team_id'] as String? ?? '',
          poleLocked: body['pole']?['locked'] as bool? ?? false,
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
      if (e.response?.statusCode == 423) return const AttemptLockedOut();
      if (e.response?.statusCode == 409) return const AttemptAlreadyCaptured();
      rethrow;
    }
  }
}
