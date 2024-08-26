import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:waydowntown/get_region_path.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/game.dart';

class CodeCollectorGame extends StatefulWidget {
  final Dio dio;
  final Game game;
  final MobileScannerController? scannerController;

  const CodeCollectorGame({
    super.key,
    required this.dio,
    required this.game,
    this.scannerController,
  });

  @override
  CodeCollectorGameState createState() => CodeCollectorGameState();
}

enum CodeSubmissionState { unsubmitted, submitting, error, correct, incorrect }

class DetectedCode {
  final String code;
  CodeSubmissionState state;

  DetectedCode(this.code, {this.state = CodeSubmissionState.unsubmitted});
}

class CodeCollectorGameState extends State<CodeCollectorGame>
    with WidgetsBindingObserver {
  List<DetectedCode> detectedCodes = [];
  late MobileScannerController controller;
  Map<String, String> codeErrors = {};
  late Game currentGame;
  bool isGameComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.scannerController ?? MobileScannerController();
    currentGame = widget.game;
    startScanner();
  }

  void startScanner() {
    controller.start();
  }

  void stopScanner() {
    controller.stop();
  }

  void _showCompletionAnimation() {
    const options = ConfettiOptions(
      spread: 360,
      ticks: 50,
      gravity: 0,
      decay: 0.94,
      startVelocity: 30,
      colors: [
        Color(0xffFFE400),
        Color(0xffFFBD00),
        Color(0xffE89400),
        Color(0xffFFCA6C),
        Color(0xffFDFFB8)
      ],
    );

    void shoot() {
      Confetti.launch(context,
          options: options.copyWith(particleCount: 40, scalar: 1.2),
          particleBuilder: (index) => Star());
      Confetti.launch(context,
          options: options.copyWith(
            particleCount: 10,
            scalar: 0.75,
          ));
    }

    Timer(Duration.zero, shoot);
    Timer(const Duration(milliseconds: 100), shoot);
    Timer(const Duration(milliseconds: 200), shoot);
  }

  Future<void> submitCode(DetectedCode detectedCode) async {
    setState(() {
      detectedCode.state = CodeSubmissionState.submitting;
    });

    try {
      final response = await widget.dio.post(
        '/waydowntown/answers?include=game',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': detectedCode.code,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': currentGame.id},
              },
            },
          },
        },
      );

      if (mounted) {
        setState(() {
          if (response.data['data']['attributes']['correct']) {
            detectedCode.state = CodeSubmissionState.correct;
          } else {
            detectedCode.state = CodeSubmissionState.incorrect;
          }

          if (response.data['included'] != null) {
            final gameData = response.data['included'].firstWhere(
              (included) =>
                  included['type'] == 'games' &&
                  included['id'] == currentGame.id,
              orElse: () => null,
            );
            if (gameData != null) {
              currentGame = Game.fromJson(
                  {'data': gameData, 'included': response.data['included']},
                  existingIncarnation: currentGame.incarnation);
            }
          }

          if (currentGame.correctAnswers == currentGame.totalAnswers) {
            isGameComplete = true;
            _showCompletionAnimation();
          }
        });
      }
    } catch (e) {
      logger.e('Error submitting code: $e');
      if (mounted) {
        setState(() {
          detectedCode.state = CodeSubmissionState.error;
          codeErrors[detectedCode.code] = e.toString();
        });
      }
    }
  }

  Widget _getIconForState(CodeSubmissionState state, String code) {
    switch (state) {
      case CodeSubmissionState.unsubmitted:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 24.0);
      case CodeSubmissionState.submitting:
        return const Icon(Icons.hourglass_empty,
            color: Colors.blue, size: 24.0);
      case CodeSubmissionState.error:
        return IconButton(
          icon: const Icon(Icons.info, color: Colors.red, size: 24.0),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text(codeErrors[code] ?? 'Unknown error'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      case CodeSubmissionState.correct:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24.0);
      case CodeSubmissionState.incorrect:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Collector'),
      ),
      body: Column(
        children: [
          Text(getRegionPath(currentGame.incarnation)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Progress: ${currentGame.correctAnswers}/${currentGame.totalAnswers}',
            ),
          ),
          if (isGameComplete)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Congratulations! You have completed the game.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          isGameComplete
              ? const SizedBox()
              : Expanded(
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final code = barcode.rawValue ?? '';
                        if (code.isNotEmpty &&
                            !detectedCodes
                                .any((element) => element.code == code)) {
                          logger.d('detected new code $code');
                          if (mounted) {
                            setState(() {
                              detectedCodes.add(DetectedCode(code));
                            });
                          }
                        }
                      }
                    },
                  ),
                ),
          Expanded(
            child: ListView.builder(
              itemCount: detectedCodes.length,
              itemBuilder: (context, index) {
                DetectedCode detectedCode = detectedCodes[index];
                return ListTile(
                  title: Text(detectedCode.code),
                  leading:
                      _getIconForState(detectedCode.state, detectedCode.code),
                  onTap:
                      detectedCode.state == CodeSubmissionState.unsubmitted ||
                              detectedCode.state == CodeSubmissionState.error
                          ? () => submitCode(detectedCode)
                          : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    logger.d('didChangeAppLifecycleState $state');
    switch (state) {
      case AppLifecycleState.resumed:
        startScanner();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        stopScanner();
        break;
      case AppLifecycleState.hidden:
        stopScanner();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }
}
