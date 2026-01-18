import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
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
}
