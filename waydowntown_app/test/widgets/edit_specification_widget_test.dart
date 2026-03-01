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
import 'package:waydowntown/models/answer.dart';
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
code_collector:
  name: Code Collector
  instructions: Collect barcodes
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
    final azButtonFinder = find.byKey(const Key('region-sort-alpha'));
    final nearestButtonFinder = find.byKey(const Key('region-sort-nearest'));

    IconButton azButton = tester.widget(azButtonFinder);
    IconButton nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({}),
        equals(Theme.of(tester.element(azButtonFinder)).primaryColor));
    expect(nearestButton.style?.backgroundColor?.resolve({}), isNull);

    await tester.ensureVisible(azButtonFinder);
    await tester.tap(azButtonFinder);
    await tester.pumpAndSettle();

    azButton = tester.widget(azButtonFinder);
    nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({}),
        equals(Theme.of(tester.element(azButtonFinder)).primaryColor));
    expect(nearestButton.style?.backgroundColor?.resolve({}), isNull);

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

    // Close the dropdown before interacting with other controls.
    await tester.tap(find.text('region 1').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(nearestButtonFinder);
    await tester.tap(nearestButtonFinder);
    await tester.pumpAndSettle();

    azButton = tester.widget(azButtonFinder);
    nearestButton = tester.widget(nearestButtonFinder);

    expect(azButton.style?.backgroundColor?.resolve({}), isNull);
    expect(nearestButton.style?.backgroundColor?.resolve({}),
        equals(Theme.of(tester.element(nearestButtonFinder)).primaryColor));

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
    final regionDropdownState =
        tester.state<FormFieldState<String>>(find.byKey(const Key('region-dropdown')));
    expect(regionDropdownState.value, equals('region1'));

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
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specification,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
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

    final addRegionButton = find.byKey(const Key('region-sort-add'));
    await tester.ensureVisible(addRegionButton);
    await tester.tap(addRegionButton);
    await tester.pumpAndSettle();

    expect(find.text('Create New Region'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Name'), 'New Region');
    await tester.enterText(find.widgetWithText(TextField, 'Description'),
        'New Region Description');

    await tester.tap(find.text('Save Region'));
    await tester.pumpAndSettle();

    final regionDropdownState =
        tester.state<FormFieldState<String>>(find.byKey(const Key('region-dropdown')));
    expect(regionDropdownState.value, equals('new_region'));
  });

  testWidgets('EditSpecificationWidget displays existing answers',
      (WidgetTester tester) async {
    final specWithAnswers = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
      answers: const [
        Answer(
            id: 'a1',
            label: 'Label 1',
            answer: 'Answer text 1',
            hint: 'Hint 1'),
        Answer(
            id: 'a2',
            label: 'Label 2',
            answer: 'Answer text 2',
            hint: 'Hint 2'),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specWithAnswers,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Answers'), findsOneWidget);
    expect(find.byKey(const Key('answer-card-0')), findsOneWidget);
    expect(find.byKey(const Key('answer-card-1')), findsOneWidget);

    final answerField0 =
        tester.widget<TextField>(find.byKey(const Key('answer-text-0')));
    expect(answerField0.controller!.text, equals('Answer text 1'));

    final labelField0 =
        tester.widget<TextField>(find.byKey(const Key('answer-label-0')));
    expect(labelField0.controller!.text, equals('Label 1'));

    final hintField0 =
        tester.widget<TextField>(find.byKey(const Key('answer-hint-0')));
    expect(hintField0.controller!.text, equals('Hint 1'));
  });

  testWidgets('EditSpecificationWidget can add a new answer',
      (WidgetTester tester) async {
    final specWithNoAnswers = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
      answers: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specWithNoAnswers,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-card-0')), findsNothing);

    await tester.tap(find.byKey(const Key('add-answer')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-card-0')), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('answer-text-0')), 'New answer');
    await tester.enterText(
        find.byKey(const Key('answer-label-0')), 'New label');
    await tester.enterText(
        find.byKey(const Key('answer-hint-0')), 'New hint');

    final answerField =
        tester.widget<TextField>(find.byKey(const Key('answer-text-0')));
    expect(answerField.controller!.text, equals('New answer'));
  });

  testWidgets('EditSpecificationWidget can delete an unsaved answer',
      (WidgetTester tester) async {
    final specWithNoAnswers = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
      answers: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specWithNoAnswers,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-answer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('answer-card-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-answer-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-card-0')), findsNothing);
  });

  testWidgets(
      'EditSpecificationWidget deletes existing answer via API and removes from list',
      (WidgetTester tester) async {
    final specWithAnswers = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
      answers: const [
        Answer(
            id: 'a1',
            label: 'Label 1',
            answer: 'Answer text 1',
            hint: 'Hint 1'),
      ],
    );

    dioAdapter.onDelete(
      '/waydowntown/answers/a1',
      (server) => server.reply(204, ''),
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specWithAnswers,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-card-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete-answer-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('answer-card-0')), findsNothing);
  });

  testWidgets(
      'EditSpecificationWidget saves new and existing answers on save',
      (WidgetTester tester) async {
    final specWithAnswers = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
      answers: const [
        Answer(
            id: 'a1',
            label: 'Label 1',
            answer: 'Answer text 1',
            hint: 'Hint 1'),
      ],
    );

    dioAdapter.onPatch(
      '/waydowntown/specifications/spec1',
      (server) => server.reply(200, {
        'data': {'id': 'spec1', 'type': 'specifications'}
      }),
      data: Matchers.any,
    );

    dioAdapter.onPatch(
      '/waydowntown/answers/a1',
      (server) => server.reply(200, {
        'data': {
          'id': 'a1',
          'type': 'answers',
          'attributes': {
            'answer': 'Updated answer',
            'label': 'Label 1',
            'hint': 'Hint 1',
            'order': 1,
          }
        }
      }),
      data: Matchers.any,
    );

    dioAdapter.onPost(
      '/waydowntown/answers',
      (server) => server.reply(201, {
        'data': {
          'id': 'a2',
          'type': 'answers',
          'attributes': {
            'answer': 'Brand new answer',
            'label': null,
            'hint': null,
            'order': 2,
          }
        }
      }),
      data: Matchers.any,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: specWithAnswers,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Update existing answer
    await tester.enterText(
        find.byKey(const Key('answer-text-0')), 'Updated answer');

    // Add a new answer
    final addButton = find.byKey(const Key('add-answer'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('answer-text-1')), 'Brand new answer');

    // Save
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'scan button appears for bluetooth_collector and code_collector concepts',
      (WidgetTester tester) async {
    final btSpec = Specification(
      id: 'spec1',
      concept: 'bluetooth_collector',
      placed: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: btSpec,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    final scanButton = find.byKey(const Key('scan-answers'));
    await tester.ensureVisible(scanButton);
    expect(scanButton, findsOneWidget);

    // Change concept to code_collector
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Code Collector').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('scan-answers')));
    expect(find.byKey(const Key('scan-answers')), findsOneWidget);
  });

  testWidgets(
      'scan button does not appear for non-sensor concepts',
      (WidgetTester tester) async {
    final spec = Specification(
      id: 'spec1',
      concept: 'fill_in_the_blank',
      placed: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
          specification: spec,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan-answers')), findsNothing);
    expect(find.byKey(const Key('add-answer')), findsOneWidget);
  });

  testWidgets('EditSpecificationWidget renders empty form in create mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('New Specification'), findsOneWidget);

    final startField =
        tester.widget<TextField>(find.widgetWithText(TextField, 'Start Description'));
    expect(startField.controller!.text, isEmpty);

    final taskField =
        tester.widget<TextField>(find.widgetWithText(TextField, 'Task Description'));
    expect(taskField.controller!.text, isEmpty);

    final durationField =
        tester.widget<TextField>(find.widgetWithText(TextField, 'Duration (seconds)'));
    expect(durationField.controller!.text, isEmpty);

    expect(find.byKey(const Key('answer-card-0')), findsNothing);
  });

  testWidgets('EditSpecificationWidget creates specification via POST',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      '/waydowntown/specifications',
      (server) => server.reply(201, {
        'data': {
          'id': 'new-spec-id',
          'type': 'specifications',
          'attributes': {
            'concept': 'fill_in_the_blank',
            'task_description': 'A new task',
            'start_description': 'A new start',
            'duration': 60,
            'notes': '',
          },
        }
      }),
      data: Matchers.any,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Select concept
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in the Blank').last);
    await tester.pumpAndSettle();

    // Fill in fields
    await tester.enterText(
        find.widgetWithText(TextField, 'Task Description'), 'A new task');
    await tester.enterText(
        find.widgetWithText(TextField, 'Start Description'), 'A new start');
    await tester.tap(find.text('1m'));

    // Save
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'EditSpecificationWidget in create mode saves answers with new spec ID',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      '/waydowntown/specifications',
      (server) => server.reply(201, {
        'data': {
          'id': 'new-spec-id',
          'type': 'specifications',
          'attributes': {
            'concept': 'fill_in_the_blank',
            'task_description': 'A new task',
          },
        }
      }),
      data: Matchers.any,
    );

    dioAdapter.onPost(
      '/waydowntown/answers',
      (server) => server.reply(201, {
        'data': {
          'id': 'new-answer-id',
          'type': 'answers',
          'attributes': {
            'answer': 'Test answer',
            'label': null,
            'hint': null,
            'order': 1,
          }
        }
      }),
      data: Matchers.any,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Select concept
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in the Blank').last);
    await tester.pumpAndSettle();

    // Fill task description
    await tester.enterText(
        find.widgetWithText(TextField, 'Task Description'), 'A new task');

    // Add an answer
    final addButton = find.byKey(const Key('add-answer'));
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('answer-text-0')), 'Test answer');

    // Save
    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
  });

  testWidgets('EditSpecificationWidget in create mode shows validation errors',
      (WidgetTester tester) async {
    dioAdapter.onPost(
      '/waydowntown/specifications',
      (server) => server.reply(422, {
        'errors': [
          {
            'source': {'pointer': '/data/attributes/concept'},
            'detail': 'must be a known concept',
          },
          {
            'source': {'pointer': '/data/attributes/task_description'},
            'detail': "can't be blank",
          },
        ],
      }),
      data: Matchers.any,
    );

    await tester.pumpWidget(MaterialApp(
      home: DefaultAssetBundle(
        bundle: testAssetBundle,
        child: EditSpecificationWidget(
          dio: dio,
        ),
      ),
    ));

    await tester.pumpAndSettle();

    final saveButton = find.text('Save');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('must be a known concept'), findsOneWidget);
    expect(find.text("can't be blank"), findsOneWidget);
  });
}
