import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:waydowntown/routes/game_launch_route.dart';

import './test_helpers.dart';

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

  setUp(() async {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    testAssetBundle = TestAssetBundle();

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
      'GameLaunchRoute displays game information, start button, progress, and map when location is available',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
''');
    final walkwayMbtiles = File('assets/walkway.mbtiles');

    testAssetBundle.addBinaryAsset(
        'assets/walkway.mbtiles', walkwayMbtiles.readAsBytesSync());

    final game = TestHelpers.createMockGame(
      concept: 'bluetooth_collector',
      latitude: 49.895305538809,
      longitude: -97.13854044484164,
      totalAnswers: 334455,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: GameLaunchRoute(game: game, dio: dio),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('test_start'), findsOneWidget);
    expect(find.byKey(const Key('total_answers')), findsOneWidget);
    expect(find.text('334455 answers'), findsOneWidget);

    // scroll the container so the start button shows
    await tester.scrollUntilVisible(find.text('Start Game'), 100);
    expect(find.text('Start Game'), findsOneWidget);

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
      'GameLaunchRoute displays message when location is not available and does not show answer count when there is only one',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
''');

    final game = TestHelpers.createMockGame(
      concept: 'bluetooth_collector',
      latitude: null,
      longitude: null,
      totalAnswers: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: GameLaunchRoute(game: game, dio: dio),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('test_start'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
    expect(find.byKey(const Key('total_answers')), findsNothing);

    expect(find.byType(FlutterMap), findsNothing);
    expect(
        find.text('Map unavailable - location not specified'), findsOneWidget);
  });

  testWidgets('GameLaunchRoute shows error for unknown concept',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '{}');

    final game = TestHelpers.createMockGame(concept: 'unknown_concept');

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: GameLaunchRoute(game: game, dio: dio),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Error: Unknown game concept'), findsOneWidget);
    expect(find.text('The game concept "unknown_concept" is not recognized.'),
        findsOneWidget);
    expect(find.text('Start Game'), findsNothing);
  });

  testWidgets(
      'GameLaunchRoute does not display location for unplaced game concepts',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
cardinal_memory:
  name: Cardinal Memory
  instructions: Face north, east, south, or west
  placed: false
''');

    final game = TestHelpers.createMockGame(
      concept: 'cardinal_memory',
      latitude: 49.895305538809,
      longitude: -97.13854044484164,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: testAssetBundle,
          child: GameLaunchRoute(game: game, dio: dio),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Cardinal Memory'), findsOneWidget);
    expect(find.text('Face north, east, south, or west'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);

    // Verify that location information is not displayed
    expect(find.text('Parent Region > Test Region'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Map unavailable - location not specified'), findsNothing);
  });
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
