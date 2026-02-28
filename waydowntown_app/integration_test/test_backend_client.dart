import 'package:dio/dio.dart';

import 'test_config.dart';

/// HTTP client for test-only backend endpoints.
class TestBackendClient {
  final Dio _dio;

  TestBackendClient()
      : _dio = Dio(BaseOptions(
          baseUrl: TestConfig.apiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  /// Resets the database, creates a test user, and optionally seeds game data.
  Future<Map<String, dynamic>> resetDatabase({String? game}) async {
    final response = await _dio.post('/test/reset', data: {
      'create_user': 'true',
      if (game != null) 'game': game,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Logs in and returns access_token and renewal_token.
  Future<({String accessToken, String renewalToken})> login(
    String email,
    String password,
  ) async {
    final response = await _dio.post('/powapi/session', data: {
      'user': {'email': email, 'password': password},
    });
    final data = response.data['data'];
    return (
      accessToken: data['access_token'] as String,
      renewalToken: data['renewal_token'] as String,
    );
  }

  /// Creates a Dio instance with Bearer auth and JSON:API headers.
  Dio createAuthenticatedDio(String accessToken) {
    return Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
        'Authorization': 'Bearer $accessToken',
      },
    ));
  }

  /// Lists all runs. Returns the list of run resource objects.
  Future<List<dynamic>> listRuns(Dio dio) async {
    final response = await dio.get('/waydowntown/runs');
    return response.data['data'] as List<dynamic>;
  }

  /// Joins a run by creating a participation. Returns the participation data.
  Future<Map<String, dynamic>> joinRun(Dio dio, String runId) async {
    final response = await dio.post('/waydowntown/participations', data: {
      'data': {
        'type': 'participations',
        'relationships': {
          'run': {
            'data': {'type': 'runs', 'id': runId},
          },
        },
      },
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Marks a participation as ready.
  Future<void> markReady(Dio dio, String participationId) async {
    await dio.patch('/waydowntown/participations/$participationId', data: {
      'data': {
        'type': 'participations',
        'id': participationId,
        'attributes': {
          'ready': true,
        },
      },
    });
  }

  /// Submits an answer for a run. Returns the submission data.
  Future<Map<String, dynamic>> submitAnswer(
    Dio dio,
    String runId,
    String submission,
  ) async {
    final response = await dio.post('/waydowntown/submissions', data: {
      'data': {
        'type': 'submissions',
        'attributes': {
          'submission': submission,
        },
        'relationships': {
          'run': {
            'data': {'type': 'runs', 'id': runId},
          },
        },
      },
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
