import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/run.dart';

class OrientationMemoryGame extends StatefulWidget {
  final Run run;
  final Dio dio;
  final MotionSensors? motionSensors;

  const OrientationMemoryGame({
    super.key,
    required this.run,
    required this.dio,
    this.motionSensors,
  });

  @override
  OrientationMemoryGameState createState() => OrientationMemoryGameState();
}

class OrientationMemoryGameState extends State<OrientationMemoryGame>
    with RunStateMixin<OrientationMemoryGame> {
  double _screenOrientation = 0.0;
  late StreamSubscription<ScreenOrientationEvent> _orientationSubscription;
  List<String> pattern = [];
  String currentOrientation = '';
  String? submissionMessage;
  late MotionSensors _motionSensors;

  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  @override
  void initState() {
    super.initState();
    _motionSensors = widget.motionSensors ?? MotionSensors();
    _orientationSubscription =
        _motionSensors.screenOrientation.listen((ScreenOrientationEvent event) {
      setState(() {
        _screenOrientation = event.angle!;
        currentOrientation = getOrientation();
      });
    });
  }

  @override
  void dispose() {
    _orientationSubscription.cancel();
    super.dispose();
  }

  String getOrientation() {
    if (_screenOrientation == 90) return 'left';
    if (_screenOrientation == 0) return 'up';
    if (_screenOrientation == -90) return 'right';
    return '';
  }

  String getOrientationArrow(String orientation) {
    switch (orientation) {
      case 'left':
        return '3';
      case 'up':
        return '5';
      case 'right':
        return '#';
      default:
        return '';
    }
  }

  Future<void> submitOrientation() async {
    if (currentOrientation.isEmpty) return;

    try {
      final answer = widget.run.specification.answers!
          .firstWhere((answer) => answer.order == pattern.length + 1);

      final isCorrect =
          await submitSubmission(currentOrientation, answerId: answer.id);

      setState(() {
        if (isCorrect) {
          pattern.add(currentOrientation);
          submissionMessage = 'Correct! Keep going.';

          if (currentRun.isComplete) {
            submissionMessage = 'Congratulations!';
          }
        } else {
          submissionMessage =
              pattern.isEmpty ? 'Incorrect.' : 'Incorrect. Start over.';
          pattern = [];
        }
      });
    } catch (e) {
      setState(() {
        submissionMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orientation Memory'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Progress: ${currentRun.correctSubmissions} / ${currentRun.totalAnswers}',
              key: const Key('progress-display'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Current pattern: '),
                Text(
                  pattern.map(getOrientationArrow).join(" "),
                  key: const Key('pattern-arrows'),
                  style: const TextStyle(fontFamily: 'arrows', fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: Key('submit-$currentOrientation'),
              onPressed: isGameComplete ? null : submitOrientation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getOrientationArrow(currentOrientation),
                    style: const TextStyle(fontFamily: 'arrows', fontSize: 72),
                  ),
                  const Text('Submit'),
                ],
              ),
            ),
            if (submissionMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(submissionMessage!),
              ),
          ],
        ),
      ),
    );
  }
}
