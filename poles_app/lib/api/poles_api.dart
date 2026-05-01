import 'package:dio/dio.dart';
import 'package:poles/models/pole.dart';
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
    await UserService.setUserData(
      user['id'] as String,
      user['email'] as String,
      name: user['name'] as String?,
      teamId: team?['id'] as String?,
      teamName: team?['name'] as String?,
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
      final code = e.response?.data?['error']?['code'];
      final poleJson = e.response?.data?['pole'] as Map<String, dynamic>?;
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
      return AttemptIncorrect(body['attempts_remaining'] as int);
    } on DioException catch (e) {
      final code = e.response?.data?['error']?['code'];
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

  Future<void> logout() async {
    try {
      await dio.delete('/powapi/session');
    } catch (_) {
      // Ignore — we're clearing local state regardless.
    }
    await UserService.clearUserData();
  }
}
