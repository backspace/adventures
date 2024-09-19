import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/run.dart';

class CardinalMemoryGame extends StatefulWidget {
  final Run run;
  final Dio dio;
  final MotionSensors? motionSensors;

  const CardinalMemoryGame({
    super.key,
    required this.run,
    required this.dio,
    this.motionSensors,
  });

  @override
  CardinalMemoryGameState createState() => CardinalMemoryGameState();
}

class CardinalMemoryGameState extends State<CardinalMemoryGame>
    with RunStateMixin<CardinalMemoryGame> {
  late StreamSubscription<AbsoluteOrientationEvent> _orientationSubscription;
  List<String> pattern = [];
  String currentDirection = '';
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
    _orientationSubscription = _motionSensors.absoluteOrientation
        .listen((AbsoluteOrientationEvent event) {
      setState(() {
        currentDirection = getCardinalDirection(event.yaw);
      });
    });
  }

  @override
  void dispose() {
    _orientationSubscription.cancel();
    super.dispose();
  }

  String getCardinalDirection(double yaw) {
    final degrees = (yaw * 180 / math.pi) % 360;
    if (degrees >= 315 || degrees < 45) return 'north';
    if (degrees >= 45 && degrees < 135) return 'west';
    if (degrees >= 135 && degrees < 225) return 'south';
    return 'east';
  }

  String getDirectionArrow(String direction) {
    switch (direction) {
      case 'north':
        return '5';
      case 'east':
        return '#';
      case 'south':
        return '%';
      case 'west':
        return '3';
      default:
        return '';
    }
  }

  Future<void> submitDirection() async {
    if (currentDirection.isEmpty) return;

    try {
      final answer = widget.run.specification.answers!
          .firstWhere((answer) => answer.order == pattern.length + 1);

      final isCorrect =
          await submitSubmission(currentDirection, answerId: answer.id);

      setState(() {
        if (isCorrect) {
          pattern.add(currentDirection);
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
        title: const Text('Cardinal Memory'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Current pattern: '),
                Text(
                  pattern.map(getDirectionArrow).join(" "),
                  key: const Key('pattern-arrows'),
                  style: const TextStyle(fontFamily: 'arrows', fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: Key('submit-$currentDirection'),
              onPressed: isGameComplete ? null : submitDirection,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getDirectionArrow(currentDirection),
                    style: const TextStyle(fontFamily: 'arrows', fontSize: 72),
                  ),
                  Text(currentDirection.toUpperCase()),
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
