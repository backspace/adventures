import 'package:dio/dio.dart';

import 'test_config.dart';

/// Credentials for a test user returned by the backend's reset endpoint.
class TestUserCredentials {
  final String userId;
  final String email;
  final String password;

  TestUserCredentials({
    required this.userId,
    required this.email,
    required this.password,
  });

  factory TestUserCredentials.fromJson(Map<String, dynamic> json) {
    return TestUserCredentials(
      userId: json['user_id'],
      email: json['email'],
      password: json['password'],
    );
  }
}

/// Tokens returned by the login endpoint.
class TestTokens {
  final String accessToken;
  final String renewalToken;

  TestTokens({
    required this.accessToken,
    required this.renewalToken,
  });
}

/// HTTP client for test setup operations against the backend.
class TestBackendClient {
  final Dio _dio;
  final String baseUrl;

  TestBackendClient({String? baseUrl})
      : baseUrl = baseUrl ?? TestConfig.apiBaseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl ?? TestConfig.apiBaseUrl,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  /// Resets the database and optionally creates a test user.
  /// Returns credentials if [createUser] is true.
  Future<TestUserCredentials?> resetDatabase({bool createUser = true}) async {
    final response = await _dio.post(
      '/test/reset',
      data: {
        'create_user': createUser ? 'true' : 'false',
      },
    );

    if (createUser && response.statusCode == 200) {
      return TestUserCredentials.fromJson(response.data);
    }
    return null;
  }

  /// Logs in with the given credentials and returns tokens.
  Future<TestTokens> login(String email, String password) async {
    final response = await _dio.post(
      '/powapi/session',
      data: {
        'user': {
          'email': email,
          'password': password,
        },
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed with status ${response.statusCode}');
    }

    final data = response.data['data'];
    return TestTokens(
      accessToken: data['access_token'],
      renewalToken: data['renewal_token'],
    );
  }
}
