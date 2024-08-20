import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/routes/code_collector_game.dart';

import './code_collector_game_test.mocks.dart';

@GenerateMocks([MobileScannerController])
void main() {
  const submitAnswerRoute = '/waydowntown/answers?include=game';

  late Dio dio;
  late DioAdapter dioAdapter;

  final Game game = Game(
    id: '22261813-2171-453f-a669-db08edc70d6d',
    incarnation: Incarnation(
      id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
      concept: 'code_collector',
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
  );

  late MockMobileScannerController mockController;

  setUp(() {
    mockController = MockMobileScannerController();
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
  });

  testWidgets('CodeCollectorGame displays scanned codes',
      (WidgetTester tester) async {
    when(mockController.start()).thenAnswer((_) async => ());
    when(mockController.autoStart).thenReturn(true);
    when(mockController.value).thenReturn(const MobileScannerState(
        availableCameras: 1,
        cameraDirection: CameraFacing.back,
        isInitialized: true,
        isRunning: true,
        size: Size(100, 100),
        torchState: TorchState.off,
        zoomScale: 1.0));

    final streamController = StreamController<BarcodeCapture>();
    when(mockController.barcodes).thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: CodeCollectorGame(
          dio: dio, game: game, scannerController: mockController),
    ));

    expect(find.text('Portage Place > Food Court'), findsOneWidget);

    streamController.add(const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'Code1', format: BarcodeFormat.qrCode)]));
    streamController.add(const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'Code2', format: BarcodeFormat.qrCode)]));

    await tester.pumpAndSettle();

    expect(find.text('Code1'), findsOneWidget);
    expect(find.text('Code2'), findsOneWidget);
  });

  testWidgets('CodeCollectorGame submits code and updates state',
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
              "attributes": {"answer": "Code1", "correct": true},
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d"
                  }
                }
              }
            },
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Code1',
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
                "answer": "Code2",
                "correct": false,
              },
              "relationships": {
                "game": {
                  "data": {
                    "type": "games",
                    "id": "22261813-2171-453f-a669-db08edc70d6d"
                  }
                }
              }
            },
            "meta": {}
          },
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Code2',
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
        (server) => server.throws(
          500,
          DioException(
            requestOptions: RequestOptions(path: submitAnswerRoute),
            error: 'Server error',
          ),
        ),
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': 'Code3',
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

    when(mockController.start()).thenAnswer((_) async => ());
    when(mockController.autoStart).thenReturn(true);
    when(mockController.value).thenReturn(const MobileScannerState(
        availableCameras: 1,
        cameraDirection: CameraFacing.back,
        isInitialized: true,
        isRunning: true,
        size: Size(100, 100),
        torchState: TorchState.off,
        zoomScale: 1.0));

    final streamController = StreamController<BarcodeCapture>();
    when(mockController.barcodes).thenAnswer((_) => streamController.stream);

    await tester.pumpWidget(MaterialApp(
      home: CodeCollectorGame(
          dio: dio, game: game, scannerController: mockController),
    ));

    streamController.add(const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'Code1', format: BarcodeFormat.qrCode)]));
    streamController.add(const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'Code2', format: BarcodeFormat.qrCode)]));
    streamController.add(const BarcodeCapture(
        barcodes: [Barcode(rawValue: 'Code3', format: BarcodeFormat.qrCode)]));

    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.grey),
        findsNWidgets(3));

    await tester.tap(find.text('Code1'));
    await tester.pump();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.blue),
        findsOneWidget);

    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.green),
        findsOneWidget);

    await tester.tap(find.text('Code2'));
    await tester.pumpAndSettle();

    expect(
        find.byWidgetPredicate((widget) =>
            widget is ListTile &&
            widget.leading is Icon &&
            (widget.leading as Icon).color == Colors.orange),
        findsOneWidget);

    await tester.tap(find.text('Code3'));
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
  });
}
