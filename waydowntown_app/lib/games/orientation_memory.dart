import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

class OrientationMemoryGame extends StatefulWidget {
  final Run game;
  final Dio dio;
  final MotionSensors? motionSensors;

  const OrientationMemoryGame({
    super.key,
    required this.game,
    required this.dio,
    this.motionSensors,
  });

  @override
  OrientationMemoryGameState createState() => OrientationMemoryGameState();
}

class OrientationMemoryGameState extends State<OrientationMemoryGame> {
  double _screenOrientation = 0.0;
  late StreamSubscription<ScreenOrientationEvent> _orientationSubscription;
  List<String> pattern = [];
  String currentOrientation = '';
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
    _orientationSubscription =
        _motionSensors.screenOrientation.listen((ScreenOrientationEvent event) {
      setState(() {
        _screenOrientation = event.angle!;
        currentOrientation = getOrientation();
      });
    });
    totalAnswers = widget.game.totalAnswers;
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
      final Response response;
      final newPattern = [...pattern, currentOrientation];

      final data = {
        'data': {
          ...(lastAnswerId != null ? {'id': lastAnswerId} : {}),
          'type': 'answers',
          'attributes': {
            'answer': newPattern.join('|'),
          },
          'relationships': {
            'game': {
              'data': {
                'type': 'games',
                'id': widget.game.id,
              }
            }
          }
        }
      };

      if (lastAnswerId != null) {
        response = await widget.dio.patch(
          '/waydowntown/answers/$lastAnswerId',
          data: data,
        );
      } else {
        response = await widget.dio.post(
          '/waydowntown/answers',
          data: data,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        final answerData = responseData['data'];
        final gameData = (responseData['included'] as List<dynamic>)
            .firstWhere((included) => included['type'] == 'games');

        if (answerData['attributes']['correct'] == true) {
          setState(() {
            pattern = newPattern;
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
        title: const Text('Orientation Memory'),
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
                  pattern.map(getOrientationArrow).join(" "),
                  key: const Key('pattern-arrows'),
                  style: const TextStyle(fontFamily: 'arrows', fontSize: 24),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: Key('submit-$currentOrientation'),
              onPressed: isGameOver ? null : submitOrientation,
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
