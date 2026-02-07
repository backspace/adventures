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

/// Game data returned when creating test games.
class TestGameData {
  final String specificationId;
  final String answerId;
  final String correctAnswer;

  TestGameData({
    required this.specificationId,
    required this.answerId,
    required this.correctAnswer,
  });

  factory TestGameData.fromJson(Map<String, dynamic> json) {
    return TestGameData(
      specificationId: json['specification_id'],
      answerId: json['answer_id'],
      correctAnswer: json['correct_answer'],
    );
  }
}

/// Combined response from reset endpoint with user and optional game data.
class TestSetupData {
  final TestUserCredentials credentials;
  final TestGameData? gameData;

  TestSetupData({
    required this.credentials,
    this.gameData,
  });
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

  /// Resets the database and optionally creates a test user and game.
  /// Returns credentials if [createUser] is true.
  /// If [game] is specified, creates test data for that game type.
  Future<TestSetupData?> resetDatabase({
    bool createUser = true,
    String? game,
  }) async {
    final response = await _dio.post(
      '/test/reset',
      data: {
        'create_user': createUser ? 'true' : 'false',
        if (game != null) 'game': game,
      },
    );

    if (createUser && response.statusCode == 200) {
      final credentials = TestUserCredentials.fromJson(response.data);
      TestGameData? gameData;

      if (game != null && response.data['specification_id'] != null) {
        gameData = TestGameData.fromJson(response.data);
      }

      return TestSetupData(credentials: credentials, gameData: gameData);
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
