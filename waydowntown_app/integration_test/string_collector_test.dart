import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waydowntown/refresh_token_interceptor.dart';
import 'package:waydowntown/services/user_service.dart';

import 'test_backend_client.dart';
import 'test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendClient testClient;
  late TestSetupData setupData;
  late TestTokens tokens;
  late Dio dio;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});

    testClient = TestBackendClient();

    // Reset database and create test user with string_collector game
    final data = await testClient.resetDatabase(
      createUser: true,
      game: 'string_collector',
    );
    setupData = data!;

    // Login to get tokens
    tokens = await testClient.login(
      setupData.credentials.email,
      setupData.credentials.password,
    );

    await UserService.setTokens(tokens.accessToken, tokens.renewalToken);

    // Create authenticated Dio instance
    dio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    final renewalDio = Dio(BaseOptions(baseUrl: TestConfig.apiBaseUrl));
    final postRenewalDio = Dio(BaseOptions(
      baseUrl: TestConfig.apiBaseUrl,
      headers: {
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    ));

    dio.interceptors.add(RefreshTokenInterceptor(
      dio: dio,
      renewalDio: renewalDio,
      postRenewalDio: postRenewalDio,
    ));
  });

  testWidgets('string_collector game: collect all items to win',
      (WidgetTester tester) async {
    // Verify game data
    expect(setupData.gameData, isNotNull);
    expect(setupData.gameData!.totalAnswers, equals(3));
    expect(setupData.gameData!.correctAnswers,
        containsAll(['apple', 'banana', 'cherry']));

    // Create a run
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.concept]=string_collector',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];

    // Start the run
    final startRunResponse = await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );
    expect(startRunResponse.statusCode, equals(200));

    // Submit first correct answer (case insensitive)
    final submission1 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': '  APPLE  '},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
          },
        },
      },
    );
    expect(submission1.statusCode, equals(201));
    expect(submission1.data['data']['attributes']['correct'], isTrue);

    // Check progress
    var runData = (submission1.data['included'] as List)
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runData['attributes']['correct_submissions'], equals(1));
    expect(runData['attributes']['total_answers'], equals(3));
    expect(runData['attributes']['complete'], isFalse);

    // Submit incorrect answer
    final wrongSubmission = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'wrong'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
          },
        },
      },
    );
    expect(wrongSubmission.statusCode, equals(201));
    expect(wrongSubmission.data['data']['attributes']['correct'], isFalse);

    // Submit second correct answer
    final submission2 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'banana'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
          },
        },
      },
    );
    expect(submission2.statusCode, equals(201));
    expect(submission2.data['data']['attributes']['correct'], isTrue);

    runData = (submission2.data['included'] as List)
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runData['attributes']['correct_submissions'], equals(2));
    expect(runData['attributes']['complete'], isFalse);

    // Submit third correct answer - should win
    final submission3 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'Cherry'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
          },
        },
      },
    );
    expect(submission3.statusCode, equals(201));
    expect(submission3.data['data']['attributes']['correct'], isTrue);

    // Verify win
    runData = (submission3.data['included'] as List)
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runData['attributes']['correct_submissions'], equals(3));
    expect(runData['attributes']['complete'], isTrue);
  });

  testWidgets('string_collector game: rejects duplicate submissions',
      (WidgetTester tester) async {
    expect(setupData.gameData, isNotNull);

    // Create and start a run
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.concept]=string_collector',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];

    await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );

    // Submit first answer
    final submission1 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'apple'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
          },
        },
      },
    );
    expect(submission1.statusCode, equals(201));

    // Try to submit same answer again (should be rejected)
    try {
      await dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {'submission': '  Apple  '}, // same, different case
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': runId},
              },
            },
          },
        },
      );
      fail('Expected 422 error for duplicate submission');
    } on DioException catch (e) {
      expect(e.response?.statusCode, equals(422));
      expect(e.response?.data['errors'][0]['detail'],
          equals('Submission already submitted'));
    }
  });
}
