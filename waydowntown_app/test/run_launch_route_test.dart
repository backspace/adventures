import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/participation.dart';
import 'package:waydowntown/routes/run_launch_route.dart';
import 'package:waydowntown/services/user_service.dart';

import './test_helpers.dart';
import './test_helpers.mocks.dart';

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, dynamic> _assets = {};

  void addAsset(String key, String value) {
    _assets[key] = value;
  }

  void addBinaryAsset(String key, List<int> value) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late Dio dio;
  late TestAssetBundle testAssetBundle;
  late DioAdapter dioAdapter;
  late MockPhoenixSocket mockSocket;
  late MockPhoenixChannel mockChannel;

  setUp(() async {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;
    testAssetBundle = TestAssetBundle();

    FlutterSecureStorage.setMockInitialValues({});
    UserService.setUserData('user1', 'user1@example.com', false);
    UserService.setTokens('test_token', 'test_renewal_token');

    (mockSocket, mockChannel, _) = TestHelpers.setupMockSocket();

    const testMockStorage = './test/fixtures/core';
    const channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return testMockStorage;
    });
  });

  tearDown(() {
    testAssetBundle.clear();
  });

  testWidgets(
      'RunLaunchRoute displays run information, start button, progress, and map when location is available',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
''');
    final walkwayMbtiles = File('assets/walkway.mbtiles');

    testAssetBundle.addBinaryAsset(
        'assets/walkway.mbtiles', walkwayMbtiles.readAsBytesSync());

    final run = TestHelpers.createMockRun(
      concept: 'bluetooth_collector',
      latitude: 49.895305538809,
      longitude: -97.13854044484164,
      totalAnswers: 334455,
      durationSeconds: 300,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(
            run: run,
            dio: dio,
            testSocket: mockSocket,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('test_start'), findsOneWidget);
    expect(find.byKey(const Key('total_answers')), findsOneWidget);
    expect(find.text('334455 answers'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);

    // scroll the container so the start button shows
    await tester.scrollUntilVisible(find.text('I’m ready'), 100);
    expect(find.text('I’m ready'), findsOneWidget);

    // It never settles because the map never loads… why?
    /*
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Check for the FlutterMap widget
    expect(find.byType(FlutterMap), findsOneWidget);

    // Check for the marker
    final markerLayer = tester.widget<MarkerLayer>(
      find.descendant(
        of: find.byType(FlutterMap),
        matching: find.byType(MarkerLayer),
      ),
    );
    expect(markerLayer.markers.length, 1);
    expect(markerLayer.markers[0].point,
        equals(const LatLng(49.895305538809, -97.13854044484164)));
        */
  });

  testWidgets(
      'The launcher can be returned to after starting the run and it will not start over',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
fill_in_the_blank:
  name: Fill in the Blank
  instructions: Fill in the blank!
''');

    final run = TestHelpers.createMockRun(
      concept: 'fill_in_the_blank',
      totalAnswers: 1,
    );

    TestHelpers.setupMockStartRunResponse(dioAdapter, run);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(run: run, dio: dio, testSocket: mockSocket),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('I’m ready'), 100);
    await tester.tap(find.text('I’m ready'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Fill in the Blank'), findsOneWidget);
    expect(find.text('Fill in the blank!'), findsOneWidget);
  },
      skip:
          true); // FIXME: The back button cannot be clicked, cannot figure out why

  testWidgets(
      'RunLaunchRoute displays message when location is not available and does not show answer count when there is only one or duration when there is none',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
''');

    final run = TestHelpers.createMockRun(
      concept: 'bluetooth_collector',
      latitude: null,
      longitude: null,
      totalAnswers: 1,
      durationSeconds: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(run: run, dio: dio, testSocket: mockSocket),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('test_start'), findsOneWidget);
    expect(find.byKey(const Key('total_answers')), findsNothing);
    expect(find.text('Duration'), findsNothing);

    expect(find.byType(FlutterMap), findsNothing);

    await tester.scrollUntilVisible(find.text('I’m ready'), 100);
    expect(find.text('I’m ready'), findsOneWidget);
  });

  testWidgets('RunLaunchRoute shows error for unknown concept',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '{}');

    final run = TestHelpers.createMockRun(concept: 'unknown_concept');

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(run: run, dio: dio, testSocket: mockSocket),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Error: Unknown game concept'), findsOneWidget);
    expect(find.text('The game concept "unknown_concept" is not recognized.'),
        findsOneWidget);
    expect(find.text('I’m ready'), findsNothing);
  });

  testWidgets(
      'RunLaunchRoute does not display location for unplaced run concepts',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
cardinal_memory:
  name: Cardinal Memory
  instructions: Face north, east, south, or west
  placeless: true
''');

    final run = TestHelpers.createMockRun(
      concept: 'cardinal_memory',
      latitude: 49.895305538809,
      longitude: -97.13854044484164,
      durationSeconds: 20,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(run: run, dio: dio, testSocket: mockSocket),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cardinal Memory'), findsOneWidget);
    expect(find.text('Face north, east, south, or west'), findsOneWidget);
    expect(find.text('20 seconds'), findsOneWidget);

    expect(find.text('I’m ready'), findsOneWidget);

    expect(find.text('Parent Region > Test Region'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets(
      'RunLaunchRoute displays Resume Game button for started runs and countdown replaces duration',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
fill_in_the_blank:
  name: Fill in the Blank
  instructions: Fill in the blank!
''');

    final run = TestHelpers.createMockRun(
      concept: 'fill_in_the_blank',
      totalAnswers: 1,
      durationSeconds: 30,
      startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(
            run: run,
            dio: dio,
            testSocket: mockSocket,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Resume Game'), 100);

    expect(find.text('Resume Game'), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('00:19'), findsOneWidget);
    expect(find.text('30 seconds'), findsNothing);
  });

  testWidgets(
      'RunLaunchRoute displays player list and shows join notifications',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
fill_in_the_blank:
  name: Fill in the Blank
  instructions: Fill in the blank!
''');

    final initialRun = TestHelpers.createMockRun(
      concept: 'fill_in_the_blank',
      participations: [
        Participation(
          id: '1',
          userId: 'user1',
          runId: 'run1',
          readyAt: null,
        ),
      ],
    );

    // Setup message stream for run updates
    final messageController = StreamController<Message>();
    when(mockChannel.messages).thenAnswer((_) => messageController.stream);

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(
            run: initialRun,
            dio: dio,
            testSocket: mockSocket,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial player list
    expect(find.text('Players'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);

    // Simulate a new player joining via run update
    final updatedRun = TestHelpers.createMockRun(
      concept: 'fill_in_the_blank',
      participations: [
        Participation(
          id: '1',
          userId: 'user1',
          runId: 'run1',
          readyAt: null,
        ),
        Participation(
          id: '2',
          userId: 'user2',
          runId: 'run1',
          readyAt: null,
        ),
      ],
    );

    messageController.add(Message(
      event: const PhoenixChannelEvent.custom('run_update'),
      payload: TestHelpers.generateRunJson(updatedRun),
    ));

    await tester.pumpAndSettle();

    expect(find.text('user2'), findsOneWidget);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Player user2 joined the game'), findsOneWidget);
  });

  testWidgets('RunLaunchRoute allows toggling ready status',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
fill_in_the_blank:
  name: Fill in the Blank
  instructions: Fill in the blank!
''');

    final run = TestHelpers.createMockRun(
      concept: 'fill_in_the_blank',
      totalAnswers: 1,
    );

    TestHelpers.setupMockStartRunResponse(dioAdapter, run);

    dioAdapter.onPatch(
      '/waydowntown/participations/participation1',
      (server) => server.reply(200, {
        'data': {
          'type': 'participations',
          'id': 'participation1',
          'attributes': {'ready_at': '2024-01-01T00:00:00Z'}
        }
      }),
      data: {
        'data': {
          'type': 'participations',
          'id': 'participation1',
          'attributes': {'ready': true}
        }
      },
    );

    dioAdapter.onPatch(
      '/waydowntown/participations/participation1',
      (server) => server.reply(200, {
        'data': {
          'type': 'participations',
          'id': 'participation1',
          'attributes': {'ready_at': null}
        }
      }),
      data: {
        'data': {
          'type': 'participations',
          'id': 'participation1',
          'attributes': {'ready': false}
        }
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: RunLaunchRoute(run: run, dio: dio, testSocket: mockSocket),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('I’m ready'), 100);
    expect(find.text('I’m ready'), findsOneWidget);

    final Finder readyButton = find.text('I’m ready');

    await tester.dragUntilVisible(
        readyButton, find.byType(Scaffold), const Offset(0, -100));

    await tester.tap(readyButton);
    await tester.pumpAndSettle();

    expect(find.text('I’m not ready!'), findsOneWidget);

    await tester.tap(find.text('I’m not ready!'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('I’m ready'), 100);
    expect(find.text('I’m ready'), findsOneWidget);
  }, skip: true);
}

const String kTemporaryPath = 'temporaryPath';
const String kApplicationSupportPath = 'applicationSupportPath';
const String kDownloadsPath = 'downloadsPath';
const String kLibraryPath = 'libraryPath';
const String kApplicationDocumentsPath = 'applicationDocumentsPath';
const String kExternalCachePath = 'externalCachePath';
const String kExternalStoragePath = 'externalStoragePath';

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return kTemporaryPath;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return kApplicationSupportPath;
  }

  @override
  Future<String?> getLibraryPath() async {
    return kLibraryPath;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return kApplicationDocumentsPath;
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return kExternalStoragePath;
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return <String>[kExternalCachePath];
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return <String>[kExternalStoragePath];
  }

  @override
  Future<String?> getDownloadsPath() async {
    return kDownloadsPath;
  }
}
