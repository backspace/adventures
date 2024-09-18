import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/run_header.dart';

class CodeCollectorGame extends StatefulWidget {
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
  CodeCollectorGameState createState() => CodeCollectorGameState();
}

enum CodeSubmissionState { unsubmitted, submitting, error, correct, incorrect }

class DetectedCode {
  final String code;
  CodeSubmissionState state;

  DetectedCode(this.code, {this.state = CodeSubmissionState.unsubmitted});
}

class CodeCollectorGameState extends State<CodeCollectorGame>
    with WidgetsBindingObserver, RunStateMixin<CodeCollectorGame> {
  List<DetectedCode> detectedCodes = [];
  late MobileScannerController controller;
  Map<String, String> codeErrors = {};

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.scannerController ?? MobileScannerController();
    startScanner();
  }

  void startScanner() {
    controller.start();
  }

  void stopScanner() {
    controller.stop();
  }

  Future<void> submitCode(DetectedCode detectedCode) async {
    setState(() {
      detectedCode.state = CodeSubmissionState.submitting;
    });

    try {
      final isCorrect = await submitSubmission(detectedCode.code);

      setState(() {
        if (isCorrect) {
          detectedCode.state = CodeSubmissionState.correct;
        } else {
          detectedCode.state = CodeSubmissionState.incorrect;
        }
      });
    } catch (e) {
      logger.e('Error submitting code: $e');
      setState(() {
        detectedCode.state = CodeSubmissionState.error;
        codeErrors[detectedCode.code] = e.toString();
      });
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

  void _addCode(DetectedCode code) {
    setState(() {
      int index = detectedCodes.length;
      detectedCodes.add(code);
      _listKey.currentState?.insertItem(index);
    });
  }

  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    DetectedCode detectedCode = detectedCodes[index];
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: ListTile(
        title: Text(detectedCode.code),
        leading: _getIconForState(detectedCode.state, detectedCode.code),
        onTap: detectedCode.state == CodeSubmissionState.unsubmitted ||
                detectedCode.state == CodeSubmissionState.error
            ? () => submitCode(detectedCode)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Collector'),
      ),
      body: Column(
        children: [
          RunHeader(run: currentRun),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Progress: ${currentRun.correctSubmissions}/${currentRun.totalAnswers}',
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
                            _addCode(DetectedCode(code));
                          }
                        }
                      }
                    },
                  ),
                ),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: detectedCodes.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(context, index, animation);
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
