import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/region.dart';
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

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) =>
      Future.value(Position(
        latitude: 49.895077,
        longitude: -97.138451,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      ));
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
            durationSeconds: 100,
            region: Region(id: 'region1', name: 'Region 1'))
        .specification;

    dioAdapter.onGet(
      '/waydowntown/regions',
      (server) => server.reply(200, {
        'data': [
          {
            'id': 'region1',
            'type': 'regions',
            'attributes': {'name': 'region 1'},
            'relationships': {
              'parent': {'data': null}
            }
          },
          {
            'id': 'region2',
            'type': 'regions',
            'attributes': {'name': 'Region 2'},
            'relationships': {
              'parent': {
                'data': {'id': 'region1', 'type': 'regions'}
              },
            }
          },
          {
            'id': 'region3',
            'type': 'regions',
            'attributes': {'name': 'Region 3'},
            'relationships': {
              'parent': {'data': null},
            }
          }
        ]
      }),
    );

    dioAdapter.onGet(
      '/waydowntown/regions?filter[position]=49.895077,-97.138451',
      (server) => server.reply(200, {
        'data': [
          {
            'id': 'region1',
            'type': 'regions',
            'attributes': {
              'name': 'region 1',
              'distance': 500,
            },
            'relationships': {
              'parent': {
                'data': {'id': 'region0', 'type': 'regions'}
              }
            }
          },
          {
            'id': 'region2',
            'type': 'regions',
            'attributes': {
              'name': 'Region 2',
              'distance': 1500,
            },
            'relationships': {
              'parent': {'data': null},
            }
          },
          {
            'id': 'region3',
            'type': 'regions',
            'attributes': {
              'name': 'Region 3',
              'distance': 2500,
            },
            'relationships': {
              'parent': {'data': null},
            }
          }
        ],
        'included': [
          {
            'id': 'region0',
            'type': 'regions',
            'attributes': {
              'name': 'Region 0',
              'distance': 5500,
            },
            'relationships': {
              'parent': {'data': null}
            }
          },
        ]
      }),
    );

    GeolocatorPlatform.instance = MockGeolocatorPlatform();
  });

  testWidgets(
      'EditSpecificationWidget updates region selection and region sort can be changed',
      (WidgetTester tester) async {
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

    // Alphabetic sort by default
    final azButtonFinder = find.widgetWithText(ElevatedButton, 'A-Z');
    final nearestButtonFinder = find.widgetWithText(ElevatedButton, 'Nearest');

    ElevatedButton azButton = tester.widget(azButtonFinder);
    ElevatedButton nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        equals(Theme.of(tester.element(azButtonFinder)).primaryColor));
    expect(nearestButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        isNot(Theme.of(tester.element(nearestButtonFinder)).primaryColor));

    await tester.tap(azButtonFinder);
    await tester.pumpAndSettle();

    azButton = tester.widget(azButtonFinder);
    nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        equals(Theme.of(tester.element(azButtonFinder)).primaryColor));
    expect(
        nearestButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        isNot(equals(
            Theme.of(tester.element(nearestButtonFinder)).primaryColor)));

    // Regions should be sorted case-insensitive

    // How to check alphabetic sort?

    // No distances in dropdown
    await tester.tap(find.byKey(const Key('region-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('region 1'), findsExactly(2));
    expect(find.text('  Region 2'), findsOneWidget);
    expect(find.text('Region 3'), findsOneWidget);

    expect(find.text('500 m'), findsNothing);
    expect(find.text('2 km'), findsNothing);
    expect(find.text('3 km'), findsNothing);

    await tester.tap(nearestButtonFinder);
    await tester.pumpAndSettle();

    azButton = tester.widget(azButtonFinder);
    nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        (equals(Theme.of(tester.element(azButtonFinder)).primaryColor)));
    expect(
        nearestButton.style?.backgroundColor?.resolve({WidgetState.pressed}),
        isNot(equals(
            Theme.of(tester.element(nearestButtonFinder)).primaryColor)));

    await tester.tap(find.byKey(const Key('region-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('500 m'), findsAny);
    expect(find.text('2 km'), findsAny);
    expect(find.text('3 km'), findsAny);
  });

  testWidgets('EditSpecificationWidget updates correctly',
      (WidgetTester tester) async {
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
    expect(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('region 1'),
        ),
        findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in the Blank').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('  Region 2'), findsOneWidget); // Assert on nesting
    await tester.tap(find.text('Region 3').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Start Description'), 'New start');
    await tester.enterText(
        find.widgetWithText(TextField, 'Task Description'), 'New task');
    await tester.tap(find.text('1m'));

    await tester.enterText(
        find.widgetWithText(TextField, 'Notes'), 'Some notes');

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
            'region_id': 'region3',
            'notes': 'Some notes',
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

  testWidgets('EditSpecificationWidget can create a new region',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      '/waydowntown/regions',
      (server) => server.reply(201, {
        'data': {
          'id': 'new_region',
          'type': 'regions',
          'attributes': {
            'name': 'New Region',
            'description': 'New Region Description',
          },
        }
      }),
      data: {
        'data': {
          'type': 'regions',
          'attributes': {
            'name': 'New Region',
            'description': 'New Region Description',
          },
        },
      },
    );

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

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.text('Create New Region'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Name'), 'New Region');
    await tester.enterText(find.widgetWithText(TextField, 'Description'),
        'New Region Description');

    await tester.tap(find.text('Save Region'));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('New Region'),
        ),
        findsOneWidget);
  });
}
