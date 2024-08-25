import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:motion_sensors/motion_sensors.dart';
import 'package:waydowntown/models/game.dart';

class OrientationMemoryGame extends StatefulWidget {
  final Game game;
  final Dio dio;
  final MotionSensors? motionSensors;

  const OrientationMemoryGame({
    Key? key,
    required this.game,
    required this.dio,
    this.motionSensors,
  }) : super(key: key);

  @override
  _OrientationMemoryGameState createState() => _OrientationMemoryGameState();
}

class _OrientationMemoryGameState extends State<OrientationMemoryGame> {
  double _screenOrientation = 0.0;
  late StreamSubscription<ScreenOrientationEvent> _orientationSubscription;
  List<String> pattern = [];
  String currentOrientation = '';
  bool isGameOver = false;
  String? lastAnswerId;
  String? submissionMessage;
  late MotionSensors _motionSensors;

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
    if (_screenOrientation > -15 && _screenOrientation < 15) return 'up';
    if (_screenOrientation > 75 && _screenOrientation < 105) return 'right';
    if (_screenOrientation < -75 && _screenOrientation > -105) return 'left';
    return '';
  }

  Future<void> submitOrientation() async {
    if (currentOrientation.isEmpty) return;

    try {
      final Response response;
      final newPattern = [...pattern, currentOrientation];

      if (lastAnswerId != null) {
        // PATCH if we have a previous correct answer
        response = await widget.dio.patch(
          '/waydowntown/answers/${lastAnswerId}?include=game',
          data: {
            'data': {
              'type': 'answers',
              'id': lastAnswerId,
              'attributes': {
                'answer': newPattern.join('|'),
              },
            }
          },
        );
      } else {
        // POST for the first answer or after an incorrect answer
        response = await widget.dio.post(
          '/waydowntown/answers?include=game',
          data: {
            'data': {
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
          },
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        final answerData = responseData['data'];
        final gameData = responseData['included'][0];

        if (answerData['attributes']['correct'] == true) {
          setState(() {
            pattern = newPattern;
            lastAnswerId = answerData['id'];
            submissionMessage = 'Correct! Keep going.';
            if (gameData['attributes']['complete'] == true) {
              isGameOver = true;
              submissionMessage = 'Congratulations! You completed the pattern.';
            }
          });
        } else {
          setState(() {
            pattern = [];
            lastAnswerId = null;
            submissionMessage = 'Incorrect. Start over.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orientation Memory'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Current pattern: ${pattern.join("|")}'),
            SizedBox(height: 20),
            Text('Current orientation: $currentOrientation'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isGameOver ? null : submitOrientation,
              child: Text(isGameOver ? 'Game Over' : 'Submit Orientation'),
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
