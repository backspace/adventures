import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/games/collector_game.dart';
import 'package:waydowntown/models/run.dart';

class StringCollectorGame extends StatelessWidget {
  final Dio dio;
  final Run run;

  StringCollectorGame({
    Key? key,
    required this.dio,
    required this.run,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final detector = ManualStringDetector();
    return CollectorGame(
      dio: dio,
      run: run,
      detector: detector,
      autoSubmit: true,
      inputBuilder: (context, detector) =>
          _buildInputWidget(context, detector as ManualStringDetector),
    );
  }

  static Widget _buildInputWidget(
      BuildContext context, ManualStringDetector detector) {
    final textController = TextEditingController();
    final focusNode = FocusNode();

    void submitString() {
      if (textController.text.isNotEmpty) {
        detector.addString(textController.text);
        textController.clear();
        focusNode.requestFocus();
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: textController,
            focusNode: focusNode,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Enter a string!',
            ),
            onSubmitted: (_) => submitString(),
          ),
        ),
        ElevatedButton(
          onPressed: submitString,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class ManualStringDetector implements StringDetector {
  final _detectedStringsController = StreamController<String>.broadcast();

  @override
  Stream<String> get detectedStrings => _detectedStringsController.stream;

  void addString(String value) {
    _detectedStringsController.add(value);
  }

  @override
  void startDetecting() {}

  @override
  void stopDetecting() {}

  @override
  void dispose() {
    _detectedStringsController.close();
  }
}
