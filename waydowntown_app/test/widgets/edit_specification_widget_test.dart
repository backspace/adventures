import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/widgets/edit_specification_widget.dart';

import '../test_helpers.dart';

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
  late Dio dio;
  late DioAdapter dioAdapter;
  late TestAssetBundle testAssetBundle;
  late Specification specification;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://example.com'));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = dioAdapter;

    testAssetBundle = TestAssetBundle();

    testAssetBundle.addAsset('assets/concepts.yaml', '''
bluetooth_collector:
  name: Bluetooth Collector
  instructions: Collect Bluetooth devices
fill_in_the_blank:
  name: Fill in the Blank
  instructions: Fill in the blank
another_concept:
  name: Another Concept
  instructions: Another Concept
''');

    specification = TestHelpers.createMockRun(
            concept: 'bluetooth_collector',
            start: 'This is the start',
            description: 'This is the task',
            durationSeconds: 100)
        .specification;
  });

  tearDown(() {
    testAssetBundle.clear();
  });

  testWidgets('EditSpecificationWidget updates', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specification,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Bluetooth Collector'), findsOneWidget);
    expect(find.text(specification.startDescription!), findsOneWidget);
    expect(find.text(specification.taskDescription!), findsOneWidget);
    expect(find.text(specification.duration.toString()), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in the Blank').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Start Description'), 'New start');
    await tester.enterText(
        find.widgetWithText(TextField, 'Task Description'), 'New task');
    await tester.tap(find.text('1m'));

    dioAdapter.onPatch(
      '/waydowntown/specifications/${specification.id}',
      (server) => server.reply(200, {
        'data': {'id': specification.id, 'type': 'specifications'}
      }),
      headers: {'Authorization': 'auth_token'},
      data: {
        'data': {
          'type': 'specifications',
          'id': specification.id,
          'attributes': {
            'concept': 'fill_in_the_blank',
            'start_description': 'New start',
            'task_description': 'New task',
            'duration': 60,
          },
        },
      },
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  });

  testWidgets('EditSpecificationWidget shows response errors',
      (WidgetTester tester) async {
    dioAdapter.onPatch(
      '/waydowntown/specifications/${specification.id}',
      (server) => server.reply(422, {
        'errors': [
          {
            'source': {'pointer': '/data/attributes/concept'},
            'detail': 'must be a known concept',
          },
          {
            'source': {'pointer': '/data/attributes/duration'},
            'detail': 'must be greater than 0',
          },
        ],
      }),
      data: Matchers.any,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditSpecificationWidget(
          dio: dio,
          specification: specification,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('must be a known concept'), findsOneWidget);
    expect(find.text('must be greater than 0'), findsOneWidget);
  });
}
