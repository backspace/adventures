import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/flutter_blue_plus_mockable.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/routes/bluetooth_collector_game.dart';

import './bluetooth_collector_game_test.mocks.dart';

@GenerateMocks([
  FlutterBluePlusMockable,
  BluetoothDevice,
  ScanResult,
])
void main() {
  const submitAnswerRoute = '/waydowntown/answers?include=game';

  final ScanResult deviceResult1 = MockScanResult();
  final BluetoothDevice device1 = MockBluetoothDevice();

  final ScanResult deviceResult2 = MockScanResult();
  final BluetoothDevice device2 = MockBluetoothDevice();

  final ScanResult deviceResult3 = MockScanResult();
  final BluetoothDevice device3 = MockBluetoothDevice();

  late Dio dio;
  late DioAdapter dioAdapter;

  final Game game = Game(
    id: '22261813-2171-453f-a669-db08edc70d6d',
    incarnation: Incarnation(
      id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
      concept: 'bluetooth_collector',
      mask: 'not applicable',
      region: Region(
        id: '324fd8f9-cd25-48be-a761-b8680fa72737',
        name: 'Food Court',
        description: null,
        parentRegion: Region(
          id: '67cc2c5c-06c2-4e86-9aac-b575fc712862',
          name: 'Portage Place',
          description: null,
        ),
      ),
    ),
    correctAnswers: 1,
    totalAnswers: 3,
  );

  late FlutterBluePlusMockable mockFlutterBluePlus;

  setUpAll(() {
    when(deviceResult1.device).thenReturn(device1);
    when(device1.platformName).thenReturn("Device 1");
    when(device1.remoteId).thenReturn(const DeviceIdentifier("1"));

    when(deviceResult2.device).thenReturn(device2);
    when(device2.platformName).thenReturn("Device 2");
    when(device2.remoteId).thenReturn(const DeviceIdentifier("2"));

    when(deviceResult3.device).thenReturn(device3);
    when(device3.platformName).thenReturn("Device 3");
    when(device3.remoteId).thenReturn(const DeviceIdentifier("3"));
  });

  setUp(() {
    mockFlutterBluePlus = MockFlutterBluePlusMockable();
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);

    when(mockFlutterBluePlus.adapterState)
        .thenAnswer((_) => Stream.fromIterable([BluetoothAdapterState.on]));

    when(mockFlutterBluePlus.startScan()).thenAnswer((_) async {});
  });

  testWidgets('BluetoothCollectorGame displays scanned devices',
      (WidgetTester tester) async {
    List<List<ScanResult>> results = [
      [deviceResult1, deviceResult2],
    ];

    when(mockFlutterBluePlus.onScanResults).thenAnswer((_) {
      return Stream.fromIterable(results);
    });

    await tester.pumpWidget(MaterialApp(
      home: BluetoothCollectorGame(
          dio: dio, game: game, flutterBluePlus: mockFlutterBluePlus),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Portage Place > Food Court'), findsOneWidget);

    expect(find.text(device1.platformName), findsOneWidget);
    expect(find.text('Device 2'), findsOneWidget);
  });

  testWidgets('BluetoothCollectorGame submits device and updates state',
      (WidgetTester tester) async {
    dioAdapter
      ..onPost(
        submitAnswerRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "7bfe9e24-fe4c-472e-b2eb-3e2c169b11c4",
              "type": "answers",
              "attributes": {"answer": "Device 1", "correct": true},
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d",
                  }
                }
              }
            },
            "included": [
              {
                "id": "22261813-2171-453f-a669-db08edc70d6d",
                "type": "games",
                "attributes": {
                  "correct_answers": 2,
                  "total_answers": 3,
                }
              }
            ],
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Device 1',
            },
            'relationships': {
              'game': {
                'data': {
                  'type': 'games',
                  'id': '22261813-2171-453f-a669-db08edc70d6d'
                }
              }
            }
          }
        },
      )
      ..onPost(
        submitAnswerRoute,
        (server) => server.reply(
          201,
          {
            "data": {
              "id": "afdc23e8-2f50-4ce6-8407-a48f5fe2643c",
              "type": "answers",
              "attributes": {
                "answer": "Device 2",
                "correct": false,
              },
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d",
                  }
                }
              }
            },
            "included": [
              {
                "id": "22261813-2171-453f-a669-db08edc70d6d",
                "type": "games",
                "attributes": {
                  "correct_answers": 2,
                  "total_answers": 3,
                }
              }
            ],
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Device 2',
            },
            'relationships': {
              'game': {
                'data': {
                  'type': 'games',
                  'id': '22261813-2171-453f-a669-db08edc70d6d'
                }
              }
            }
          }
        },
      )
      ..onPost(
        submitAnswerRoute,
        (server) {
          server.reply(500, (request) {
            // Override handler for resubmission after error
            dioAdapter.onPost(
              submitAnswerRoute,
              (server) => server.reply(201, {
                "data": {
                  "id": "48cf441e-ab98-4da6-8980-69fba3b4417d",
                  "type": "answers",
                  "attributes": {
                    "answer": "Device 3",
                    "correct": false,
                  },
                  "relationships": {
                    "game": {
                      "data": {
                        "type": "games",
                        "id": "22261813-2171-453f-a669-db08edc70d6d",
                      }
                    }
                  }
                },
                "included": [
                  {
                    "id": "22261813-2171-453f-a669-db08edc70d6d",
                    "type": "games",
                    "attributes": {
                      "correct_answers": 2,
                      "total_answers": 3,
                    }
                  }
                ],
                "meta": {}
              }),
              data: {
                'data': {
                  'type': 'answers',
                  'attributes': {
                    'answer': 'Device 3',
                  },
                  'relationships': {
                    'game': {
                      'data': {
                        'type': 'games',
                        'id': '22261813-2171-453f-a669-db08edc70d6d'
                      }
                    }
                  }
                }
              },
            );

            throw DioException(
              requestOptions: RequestOptions(path: submitAnswerRoute),
              error: 'Server error',
            );
          });
        },
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Device 3',
            },
            'relationships': {
              'game': {
                'data': {
                  'type': 'games',
                  'id': '22261813-2171-453f-a669-db08edc70d6d'
                }
              }
            }
          }
        },
      );

    List<List<ScanResult>> results = [
      [deviceResult1, deviceResult2, deviceResult3],
    ];

    when(mockFlutterBluePlus.onScanResults).thenAnswer((_) {
      return Stream.fromIterable(results);
    });

    await tester.pumpWidget(MaterialApp(
      home: BluetoothCollectorGame(
          dio: dio, game: game, flutterBluePlus: mockFlutterBluePlus),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Progress: 1/3'), findsOneWidget);

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.grey),
        findsNWidgets(3));

    await tester.tap(find.text('Device 1'));
    await tester.pump();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.blue),
        findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Progress: 2/3'), findsOneWidget);

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.green),
        findsOneWidget);

    await tester.tap(find.text('Device 2'));
    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.orange),
        findsOneWidget);

    await tester.tap(find.text('Device 3'));
    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is IconButton &&
            ((widget.leading as IconButton).icon as Icon).color == Colors.red),
        findsOneWidget);

    final errorIcon = find.byIcon(Icons.info);
    expect(errorIcon, findsOneWidget);

    await tester.tap(errorIcon);
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsOneWidget);
    expect(find.text("DioException [unknown]: null\nError: Server error"),
        findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Error'), findsNothing);

    await tester.tap(find.text('Device 3'));
    await tester.pumpAndSettle();

    expect(errorIcon, findsNothing);
  });
}
