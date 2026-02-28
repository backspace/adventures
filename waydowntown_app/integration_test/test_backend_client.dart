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
}
