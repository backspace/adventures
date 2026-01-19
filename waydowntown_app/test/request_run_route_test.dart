import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/submission.dart';
import 'package:waydowntown/routes/request_run_route.dart';
import 'package:waydowntown/routes/run_launch_route.dart';
import 'package:waydowntown/services/user_service.dart';

import './test_helpers.dart';
import './test_helpers.mocks.dart';

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, dynamic> _assets = {};

  void addAsset(String key, String value) {
    _assets[key] = value;
  }

  @override
  void clear() {
    _assets.clear();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (_assets.containsKey(key)) {
      if (_assets[key] is String) {
        return _assets[key]!;
      }
      throw FlutterError('Asset is not a string: $key');
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    if (_assets.containsKey(key)) {
      if (_assets[key] is String) {
        return ByteData.view(
            Uint8List.fromList(_assets[key]!.codeUnits).buffer);
      } else if (_assets[key] is List<int>) {
        return ByteData.view(Uint8List.fromList(_assets[key]!).buffer);
      }
    }
    throw FlutterError('Asset not found: $key');
  }
}

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late TestAssetBundle testAssetBundle;
  late MockPhoenixSocket mockSocket;

  setUp(() async {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);

    FlutterSecureStorage.setMockInitialValues({});
    await UserService.setUserData('user1', 'user1@example.com', false);
    await UserService.setTokens('test_token', 'test_renewal_token');

    testAssetBundle = TestAssetBundle();
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
payphone_collector:
  name: Payphone Collector
  instructions: Collect phone numbers
  long_running: true
''');

    (mockSocket, _, _) = TestHelpers.setupMockSocket();
  });

  tearDown(() {
    testAssetBundle.clear();
  });

  const requestRunRoute = '/waydowntown/runs';

  testWidgets('RequestRunRoute hands off to RunLaunchRoute',
      (WidgetTester tester) async {
    final mockGame = TestHelpers.createMockRun(concept: 'bluetooth_collector');

    TestHelpers.setupMockRunResponse(dioAdapter,
        route: requestRunRoute, run: mockGame);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RequestRunRoute(dio: dio, testSocket: mockSocket),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RunLaunchRoute), findsOneWidget);
  });

  testWidgets('An error is displayed when the game request fails',
      (WidgetTester tester) async {
    TestHelpers.setupMockErrorResponse(dioAdapter, requestRunRoute, data: {});

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RequestRunRoute(dio: dio, testSocket: mockSocket),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error fetching game'), findsOneWidget);
  });

  testWidgets(
      'RequestRunRoute resumes long-running runs and shows existing submissions',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final baseRun = TestHelpers.createMockRun(
      concept: 'payphone_collector',
      description: 'Collect phone numbers',
      startedAt: now.subtract(const Duration(minutes: 5)),
    );
    final run = Run(
      id: baseRun.id,
      specification: baseRun.specification,
      correctSubmissions: 1,
      totalAnswers: baseRun.totalAnswers,
      startedAt: baseRun.startedAt,
      taskDescription: baseRun.taskDescription,
      participations: baseRun.participations,
      submissions: [
        Submission(
          id: 'submission-1',
          submission: '555-1234',
          correct: true,
          insertedAt: now.subtract(const Duration(minutes: 4)),
          creatorId: 'user1',
        ),
      ],
    );

    final runJson = TestHelpers.generateRunJson(run);

    dioAdapter.onGet(
      '/waydowntown/runs?filter[started]=true&filter[specification.concept]=payphone_collector',
      (server) => server.reply(200, {
        'data': [runJson['data']],
        'included': runJson['included'],
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RequestRunRoute(dio: dio, testSocket: mockSocket),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RunLaunchRoute), findsOneWidget);
    expect(find.text('Resume Game'), findsOneWidget);

    await tester.tap(find.text('Resume Game'));
    await tester.pumpAndSettle();

    expect(find.text('555-1234'), findsOneWidget);
  });
}
