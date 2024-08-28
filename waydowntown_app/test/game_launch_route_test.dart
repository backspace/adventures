import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waydowntown/routes/game_launch_route.dart';
import './test_helpers.dart';

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, String> _assets = {};

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
      return _assets[key]!;
    }
    throw FlutterError('Asset not found: $key');
  }

  @override
  Future<ByteData> load(String key) async {
    throw UnimplementedError();
  }
}

void main() {
  late Dio dio;
  late TestAssetBundle testAssetBundle;

  setUp(() {
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());
    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    testAssetBundle = TestAssetBundle();
  });

  tearDown(() {
    testAssetBundle.clear();
  });

  testWidgets('GameLaunchRoute displays game information and start button',
      (WidgetTester tester) async {
    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
''');

    final game = TestHelpers.createMockGame(concept: 'bluetooth_collector');

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
    expect(find.text('Starting point: test_start'), findsOneWidget);
    expect(find.text('Start Game'), findsOneWidget);
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
}
