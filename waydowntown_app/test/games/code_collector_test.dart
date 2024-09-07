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
import 'package:waydowntown/games/code_collector.dart';
import 'package:waydowntown/models/game.dart';

import '../test_helpers.dart';

import 'code_collector_test.mocks.dart';

@GenerateMocks([MobileScannerController])
void main() {
  const submitAnswerRoute = '/waydowntown/answers';

  late Dio dio;
  late DioAdapter dioAdapter;
  late Game game;

  late MockMobileScannerController mockController;

  setUp(() {
    mockController = MockMobileScannerController();
    dotenv.testLoad(fileInput: File('.env').readAsStringSync());

    dio = Dio(BaseOptions(baseUrl: dotenv.env['API_ROOT']!));
    dio.interceptors.add(PrettyDioLogger());
    dioAdapter = DioAdapter(dio: dio);
    game = TestHelpers.createMockGame(
        concept: 'code_collector', correctAnswers: 0, totalAnswers: 5);
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

    expect(find.text('Parent Region > Test Region'), findsOneWidget);
    expect(find.text('test_description'), findsOneWidget);

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
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'Code1',
            correct: true,
            correctAnswers: 1,
            totalAnswers: 5));
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute, answer: 'Code2', correct: false));

    dioAdapter.onPost(
      submitAnswerRoute,
      (server) {
        server.reply(500, (request) {
          // Override handler for resubmission after error
          dioAdapter.onPost(
            submitAnswerRoute,
            (server) => server.reply(
                201,
                TestHelpers.generateAnswerResponseJson(AnswerResponse(
                  answerId: '48cf441e-ab98-4da6-8980-69fba3b4417d',
                  answer: 'Code3',
                  correct: true,
                  gameId: game.id,
                  correctAnswers: 1,
                  totalAnswers: 3,
                ))),
            data: TestHelpers.generateAnswerRequestJson('Code3', game.id),
          );

          throw DioException(
            requestOptions: RequestOptions(path: submitAnswerRoute),
            error: 'Server error',
          );
        });
      },
      data: TestHelpers.generateAnswerRequestJson('Code3', game.id),
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

    expect(find.text('Progress: 0/5'), findsOneWidget);

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

    expect(find.text('Progress: 1/5'), findsOneWidget);

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

    await tester.tap(find.text('Code3'));
    await tester.pumpAndSettle();

    expect(errorIcon, findsNothing);
  });

  testWidgets('CodeCollectorGame completes and stops scanning',
      (WidgetTester tester) async {
    TestHelpers.setupMockAnswerResponse(
        dioAdapter,
        AnswerRequest(
            route: submitAnswerRoute,
            answer: 'Code5',
            correct: true,
            correctAnswers: 5,
            totalAnswers: 5,
            isComplete: true));

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
        barcodes: [Barcode(rawValue: 'Code5', format: BarcodeFormat.qrCode)]));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Code5'));
    await tester.pumpAndSettle();

    expect(find.text('Progress: 5/5'), findsOneWidget);
    expect(find.text('Congratulations! You have completed the game.'),
        findsOneWidget);

    // This is called automatically when MobileScanner is disposed of
    verify(mockController.stop()).called(1);

    expect(find.byType(MobileScanner), findsNothing);
  });
}
