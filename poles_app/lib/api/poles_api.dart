import 'package:dio/dio.dart';
import 'package:poles/models/draft.dart';
import 'package:poles/models/pole.dart';
import 'package:poles/models/validation.dart';
import 'package:poles/services/user_service.dart';

class PolesApi {
  final Dio dio;

  PolesApi(this.dio);

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

  Future<void> loadAndStoreMe() async {
    final response = await dio.get('/poles/me');
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
  }

  Future<List<Pole>> listPoles() async {
    final response = await dio.get('/poles/poles');
    final list = response.data['poles'] as List;
    return list
        .map((p) => Pole.fromJson(p as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<ScanOutcome> scan(String barcode) async {
    try {
      final response = await dio.get('/poles/poles/$barcode');
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
        '/poles/puzzlets/$puzzletId/attempts',
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
    final response = await dio.get('/poles/drafts/mine');
    return MyDrafts.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPole> createDraftPole({
    required String barcode,
    required double latitude,
    required double longitude,
    String? label,
    String? notes,
    double? accuracyM,
  }) async {
    final response = await dio.post('/poles/drafts/poles', data: {
      'barcode': barcode,
      'latitude': latitude,
      'longitude': longitude,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> createDraftPuzzlet({
    required String instructions,
    required String answer,
    required int difficulty,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) async {
    final response = await dio.post('/poles/drafts/puzzlets', data: {
      'instructions': instructions,
      'answer': answer,
      'difficulty': difficulty,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
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
  }) async {
    final response = await dio.patch('/poles/drafts/poles/$id', data: {
      if (barcode != null) 'barcode': barcode,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> updateDraftPuzzlet(
    String id, {
    String? instructions,
    String? answer,
    int? difficulty,
    double? latitude,
    double? longitude,
    double? accuracyM,
  }) async {
    final response = await dio.patch('/poles/drafts/puzzlets/$id', data: {
      if (instructions != null) 'instructions': instructions,
      if (answer != null) 'answer': answer,
      if (difficulty != null) 'difficulty': difficulty,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
    });
    return DraftPuzzlet.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDraftPole(String id) =>
      dio.delete('/poles/drafts/poles/$id');

  Future<void> deleteDraftPuzzlet(String id) =>
      dio.delete('/poles/drafts/puzzlets/$id');

  // ────────── Validator surface ──────────

  Future<MyValidations> listMyValidations() async {
    final response = await dio.get('/poles/validation/mine');
    return MyValidations.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PoleValidationModel> transitionPoleValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/poles/validation/pole-validations/$id',
      data: {'status': status},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> transitionPuzzletValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/poles/validation/puzzlet-validations/$id',
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
      '/poles/validation/pole-validations/$validationId/comments',
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
      '/poles/validation/puzzlet-validations/$validationId/comments',
      data: {
        'field': field,
        if (comment != null) 'comment': comment,
        if (suggestedValue != null) 'suggested_value': suggestedValue,
      },
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deletePoleComment(String id) =>
      dio.delete('/poles/validation/pole-comments/$id');

  Future<void> deletePuzzletComment(String id) =>
      dio.delete('/poles/validation/puzzlet-comments/$id');

  // ────────── Supervisor surface ──────────

  Future<DashboardCounts> supervisorDashboard() async {
    final response = await dio.get('/poles/supervision/dashboard');
    return DashboardCounts.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ValidatorUser>> listValidators({String? excludeUserId}) async {
    final response = await dio.get('/poles/supervision/validators',
        queryParameters: {
          if (excludeUserId != null) 'exclude_user_id': excludeUserId
        });
    final list = response.data['validators'] as List;
    return list
        .map((e) => ValidatorUser.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<DraftPole>> supervisionListPoles({String? status}) async {
    final response = await dio.get('/poles/supervision/poles',
        queryParameters: {if (status != null) 'status': status});
    return (response.data['poles'] as List)
        .map((e) => DraftPole.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<DraftPuzzlet>> supervisionListPuzzlets({String? status}) async {
    final response = await dio.get('/poles/supervision/puzzlets',
        queryParameters: {if (status != null) 'status': status});
    return (response.data['puzzlets'] as List)
        .map((e) => DraftPuzzlet.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PoleValidationModel> assignPoleValidation(
      String poleId, String validatorId) async {
    final response = await dio.post(
      '/poles/supervision/poles/$poleId/validations',
      data: {'validator_id': validatorId},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> assignPuzzletValidation(
      String puzzletId, String validatorId) async {
    final response = await dio.post(
      '/poles/supervision/puzzlets/$puzzletId/validations',
      data: {'validator_id': validatorId},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<PoleValidationModel> supervisorTransitionPoleValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/poles/supervision/pole-validations/$id',
      data: {'status': status},
    );
    return PoleValidationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PuzzletValidationModel> supervisorTransitionPuzzletValidation(
      String id, String status) async {
    final response = await dio.patch(
      '/poles/supervision/puzzlet-validations/$id',
      data: {'status': status},
    );
    return PuzzletValidationModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> decidePoleComment(String id, String status) async {
    final response = await dio.patch(
      '/poles/supervision/pole-comments/$id',
      data: {'status': status},
    );
    return ValidationComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ValidationComment> decidePuzzletComment(
      String id, String status) async {
    final response = await dio.patch(
      '/poles/supervision/puzzlet-comments/$id',
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
  }) async {
    final response = await dio.patch('/poles/supervision/poles/$id', data: {
      if (barcode != null) 'barcode': barcode,
      if (label != null) 'label': label,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return DraftPole.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DraftPuzzlet> supervisorEditPuzzlet(
    String id, {
    String? instructions,
    String? answer,
    int? difficulty,
  }) async {
    final response = await dio.patch('/poles/supervision/puzzlets/$id', data: {
      if (instructions != null) 'instructions': instructions,
      if (answer != null) 'answer': answer,
      if (difficulty != null) 'difficulty': difficulty,
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
