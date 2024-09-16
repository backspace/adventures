import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

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

class CardinalMemoryGameState extends State<CardinalMemoryGame> {
  late StreamSubscription<AbsoluteOrientationEvent> _orientationSubscription;
  List<String> pattern = [];
  String currentDirection = '';
  bool isGameOver = false;
  String? lastAnswerId;
  String? submissionMessage;
  late MotionSensors _motionSensors;
  String? winningAnswerId;
  int totalAnswers = 0;

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
    totalAnswers = widget.run.totalAnswers;
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
      final Response response;

      final answer = widget.run.specification.answers!
          .firstWhere((answer) => answer.order == pattern.length + 1);

      final data = {
        'data': {
          'type': 'submissions',
          'attributes': {
            'submission': currentDirection,
          },
          'relationships': {
            'run': {
              'data': {
                'type': 'runs',
                'id': widget.run.id,
              }
            },
            'answer': {
              'data': {
                'type': 'answers',
                'id': answer.id,
              }
            }
          }
        }
      };

      response = await widget.dio.post(
        '/waydowntown/submissions',
        data: data,
      );

      if (response.statusCode == 201) {
        final responseData = response.data;
        final answerData = responseData['data'];
        final gameData = (responseData['included'] as List<dynamic>)
            .firstWhere((included) => included['type'] == 'runs');

        if (answerData['attributes']['correct'] == true) {
          setState(() {
            pattern.add(currentDirection);
            lastAnswerId = answerData['id'];
            submissionMessage = 'Correct! Keep going.';
            totalAnswers = gameData['attributes']['total_answers'];
            if (gameData['attributes']['complete'] == true) {
              _showCompletionAnimation();
              isGameOver = true;
              submissionMessage = 'Congratulations!';
            }
          });
        } else {
          setState(() {
            submissionMessage =
                pattern.isEmpty ? 'Incorrect.' : 'Incorrect. Start over.';
            pattern = [];
            lastAnswerId = null;
          });
        }
      } else {
        setState(() {
          submissionMessage = 'Error submitting answer. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        submissionMessage = 'Error: $e';
      });
    }
  }

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
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
            Text(
              'Progress: ${pattern.length} / $totalAnswers',
              key: const Key('progress-display'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 20),
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
              onPressed: isGameOver ? null : submitDirection,
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
