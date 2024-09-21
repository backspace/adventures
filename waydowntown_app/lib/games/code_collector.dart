import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:waydowntown/games/collector_game.dart';
import 'package:waydowntown/models/run.dart';

class CodeCollectorGame extends StatelessWidget {
  final Dio dio;
  final Run run;
  final MobileScannerController? scannerController;

  const CodeCollectorGame({
    super.key,
    required this.dio,
    required this.run,
    this.scannerController,
  });

  @override
  Widget build(BuildContext context) {
    final detector = CodeDetector(scannerController);
    return CollectorGame(
      dio: dio,
      run: run,
      detector: detector,
      inputBuilder: (context, detector) => Expanded(
        child: SizedBox(
          height: 300,
          child: MobileScanner(
            controller: (detector as CodeDetector).controller,
          ),
        ),
      ),
    );
  }
}

class CodeDetector implements StringDetector {
  final MobileScannerController controller;
  final _detectedCodesController = StreamController<String>.broadcast();
  StreamSubscription? _barcodesSubscription;

  CodeDetector(MobileScannerController? scannerController)
      : controller = scannerController ?? MobileScannerController();

  @override
  Stream<String> get detectedStrings => _detectedCodesController.stream;

  @override
  void startDetecting() {
    controller.start();
    controller.barcodes.listen((capture) {
      for (var barcode in capture.barcodes) {
        final code = barcode.rawValue ?? '';
        if (code.isNotEmpty) {
          _detectedCodesController.add(code);
        }
      }
    });
  }

  @override
  void stopDetecting() {
    controller.stop();
  }

  @override
  void dispose() {
    controller.dispose();
    _detectedCodesController.close();
  }
}
