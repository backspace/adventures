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

    // Reset database and create test user with orientation_memory game
    final data = await testClient.resetDatabase(
      createUser: true,
      game: 'orientation_memory',
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

  testWidgets('orientation_memory game: complete sequence in order to win',
      (WidgetTester tester) async {
    // Verify game data
    expect(setupData.gameData, isNotNull);
    expect(setupData.gameData!.totalAnswers, equals(3));
    expect(setupData.gameData!.orderedAnswers,
        equals(['north', 'east', 'south']));

    // Create a run using the specific specification ID (orientation_memory is placeless,
    // so we must use specification.id filter to use our test data)
    final specificationId = setupData.gameData!.specificationId;
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.id]=$specificationId',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];

    // Get answer IDs from included data (ordered by their order field)
    final included = createRunResponse.data['included'] as List;
    final answers = included
        .where((i) => i['type'] == 'answers')
        .toList()
      ..sort((a, b) =>
          (a['attributes']['order'] as int)
              .compareTo(b['attributes']['order'] as int));

    final answer1Id = answers[0]['id']; // order 1: north
    final answer2Id = answers[1]['id']; // order 2: east
    final answer3Id = answers[2]['id']; // order 3: south

    // Start the run
    final startRunResponse = await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );
    expect(startRunResponse.statusCode, equals(200));

    // Submit first answer (order 1)
    final submission1 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'north'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer1Id},
            },
          },
        },
      },
    );
    expect(submission1.statusCode, equals(201));
    expect(submission1.data['data']['attributes']['correct'], isTrue);

    // Check progress - should be 1/3
    var runData = (submission1.data['included'] as List)
        .firstWhere((i) => i['type'] == 'runs' && i['id'] == runId);
    expect(runData['attributes']['correct_submissions'], equals(1));
    expect(runData['attributes']['complete'], isFalse);

    // Submit second answer (order 2)
    final submission2 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'east'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer2Id},
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

    // Submit third answer (order 3) - should win
    final submission3 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'south'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer3Id},
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

  testWidgets('orientation_memory game: wrong order submission rejected',
      (WidgetTester tester) async {
    expect(setupData.gameData, isNotNull);

    // Create and start a run using specification ID (orientation_memory is placeless)
    final specificationId = setupData.gameData!.specificationId;
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.id]=$specificationId',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];

    // Get answer IDs
    final included = createRunResponse.data['included'] as List;
    final answers = included
        .where((i) => i['type'] == 'answers')
        .toList()
      ..sort((a, b) =>
          (a['attributes']['order'] as int)
              .compareTo(b['attributes']['order'] as int));

    final answer2Id = answers[1]['id']; // order 2: east

    await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );

    // Try to submit order 2 answer first (should fail - expected order 1)
    try {
      await dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {'submission': 'east'},
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': runId},
              },
              'answer': {
                'data': {'type': 'answers', 'id': answer2Id},
              },
            },
          },
        },
      );
      fail('Expected 422 error for wrong order submission');
    } on DioException catch (e) {
      expect(e.response?.statusCode, equals(422));
      expect(e.response?.data['errors'][0]['detail'],
          contains('Expected submission for answer of order 1'));
    }
  });

  testWidgets('orientation_memory game: wrong answer resets progress',
      (WidgetTester tester) async {
    expect(setupData.gameData, isNotNull);

    // Create and start a run using specification ID (orientation_memory is placeless)
    final specificationId = setupData.gameData!.specificationId;
    final createRunResponse = await dio.post(
      '/waydowntown/runs?filter[specification.id]=$specificationId',
      data: {
        'data': {'type': 'runs', 'attributes': {}},
      },
    );
    expect(createRunResponse.statusCode, equals(201));
    final runId = createRunResponse.data['data']['id'];

    // Get answer IDs
    final included = createRunResponse.data['included'] as List;
    final answers = included
        .where((i) => i['type'] == 'answers')
        .toList()
      ..sort((a, b) =>
          (a['attributes']['order'] as int)
              .compareTo(b['attributes']['order'] as int));

    final answer1Id = answers[0]['id']; // order 1: north
    final answer2Id = answers[1]['id']; // order 2: east

    await dio.post(
      '/waydowntown/runs/$runId/start',
      data: {
        'data': {'type': 'runs', 'id': runId},
      },
    );

    // Submit correct first answer
    final submission1 = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'north'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer1Id},
            },
          },
        },
      },
    );
    expect(submission1.statusCode, equals(201));
    expect(submission1.data['data']['attributes']['correct'], isTrue);

    // Submit WRONG answer for order 2 (wrong text, right answer_id)
    final wrongSubmission = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'wrong_direction'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer2Id},
            },
          },
        },
      },
    );
    expect(wrongSubmission.statusCode, equals(201));
    expect(wrongSubmission.data['data']['attributes']['correct'], isFalse);

    // Now we should be reset to order 1
    // Try to submit order 2 again - should fail because we're back at order 1
    try {
      await dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {'submission': 'east'},
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': runId},
              },
              'answer': {
                'data': {'type': 'answers', 'id': answer2Id},
              },
            },
          },
        },
      );
      fail('Expected 422 error - should be reset to order 1');
    } on DioException catch (e) {
      expect(e.response?.statusCode, equals(422));
      expect(e.response?.data['errors'][0]['detail'],
          contains('Expected submission for answer of order 1'));
    }

    // Submit order 1 again - should work
    final submission1Again = await dio.post(
      '/waydowntown/submissions',
      data: {
        'data': {
          'type': 'submissions',
          'attributes': {'submission': 'north'},
          'relationships': {
            'run': {
              'data': {'type': 'runs', 'id': runId},
            },
            'answer': {
              'data': {'type': 'answers', 'id': answer1Id},
            },
          },
        },
      },
    );
    expect(submission1Again.statusCode, equals(201));
    expect(submission1Again.data['data']['attributes']['correct'], isTrue);
  });
}
