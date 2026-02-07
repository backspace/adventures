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
    // Initialize mock storage for tests
    FlutterSecureStorage.setMockInitialValues({});

    testClient = TestBackendClient();

    // Reset database and create test user with fill_in_the_blank game
    final data = await testClient.resetDatabase(
      createUser: true,
      game: 'fill_in_the_blank',
    );
    setupData = data!;

    // Login to get tokens
    tokens = await testClient.login(
      setupData.credentials.email,
      setupData.credentials.password,
    );

    // Store tokens in secure storage
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

  testWidgets('fill_in_the_blank game: correct answer wins',
      (WidgetTester tester) async {
    // Verify game data was created
    expect(setupData.gameData, isNotNull);
    expect(setupData.gameData!.correctAnswer, equals('correct'));

    // Step 1: Create a run (this also creates a participation)
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.concept]=fill_in_the_blank',
      data: {
        'data': {
          'type': 'runs',
          'attributes': {},
        },
      },
    );

    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];
    expect(runId, isNotNull);

    // Verify specification is included (task_description is hidden until run starts)
    final included = createRunResponse.data['included'] as List;
    final specData = included.firstWhere((i) => i['type'] == 'specifications');
    expect(specData['attributes']['concept'], equals('fill_in_the_blank'));

    // Verify answer is included (with label but not the actual answer)
    final answerData = included.firstWhere((i) => i['type'] == 'answers');
    expect(answerData['attributes']['label'], equals('The answer is ____'));
    final answerId = answerData['id'];

    // Step 2: Start the run
    final startRunResponse = await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {
          'type': 'runs',
          'id': runId,
        },
      },
    );

    expect(startRunResponse.statusCode, equals(200));
    expect(
        startRunResponse.data['data']['attributes']['started_at'], isNotNull);

    // Now task_description should be visible on the run
    expect(startRunResponse.data['data']['attributes']['task_description'],
        equals('What is the answer to this test?'));

    // Step 3: Submit an incorrect answer first
    // Note: fill_in_the_blank requires answer_id in submission
    final wrongSubmissionResponse = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'wrong answer'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answerId},
            },
          },
        },
      },
    );

    expect(wrongSubmissionResponse.statusCode, equals(201));
    expect(
        wrongSubmissionResponse.data['data']['attributes']['correct'], isFalse);

    // Verify run is not complete yet
    final wrongIncluded = wrongSubmissionResponse.data['included'] as List;
    final runAfterWrong =
        wrongIncluded.firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runAfterWrong['attributes']['complete'], isFalse);

    // Step 4: Submit the correct answer
    final correctSubmissionResponse = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'correct'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answerId},
            },
          },
        },
      },
    );

    expect(correctSubmissionResponse.statusCode, equals(201));
    expect(correctSubmissionResponse.data['data']['attributes']['correct'],
        isTrue);

    // Verify run is now complete
    final correctIncluded = correctSubmissionResponse.data['included'] as List;
    final runAfterCorrect = correctIncluded
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runAfterCorrect['attributes']['complete'], isTrue);
  });

  testWidgets('fill_in_the_blank game: case insensitive matching',
      (WidgetTester tester) async {
    expect(setupData.gameData, isNotNull);

    // Create a run
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.concept]=fill_in_the_blank',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];
    expect(runId, isNotNull);

    // Get answer ID from included data
    final included = createRunResponse.data['included'] as List;
    final answerData = included.firstWhere((i) => i['type'] == 'answers');
    final answerId = answerData['id'];

    // Start the run
    final startRunResponse = await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );
    expect(startRunResponse.statusCode, equals(200));

    // Submit answer with different case and whitespace
    // Note: fill_in_the_blank requires answer_id in submission
    final submissionResponse = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': '  CORRECT  '},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answerId},
            },
          },
        },
      },
    );

    expect(submissionResponse.statusCode, equals(201));
    expect(submissionResponse.data['data']['attributes']['correct'], isTrue);

    // Verify run is complete
    final submissionIncluded = submissionResponse.data['included'] as List;
    final runData = submissionIncluded
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runData['attributes']['complete'], isTrue);
  });
}
