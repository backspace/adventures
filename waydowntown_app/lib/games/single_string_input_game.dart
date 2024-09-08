import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/game_header.dart';
import 'package:waydowntown/main.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

class SingleStringInputGame extends StatefulWidget {
  final Dio dio;
  final Game game;

  const SingleStringInputGame(
      {super.key, required this.dio, required this.game});

  @override
  SingleStringInputGameState createState() => SingleStringInputGameState();
}

class SingleStringInputGameState extends State<SingleStringInputGame> {
  String answer = 'answer';
  bool hasAnsweredIncorrectly = false;
  bool isOver = false;
  bool isRequestError = false;
  bool isAnswerError = false;
  bool isGameComplete = false;
  TextEditingController textFieldController = TextEditingController();

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> submitAnswer(String answer) async {
    try {
      final response = await widget.dio.post(
        '/waydowntown/answers',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': answer,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': widget.game.id},
              },
            },
          },
        },
      );

      setState(() {
        isAnswerError = false;
        isOver = checkGameCompletion(response.data);
        hasAnsweredIncorrectly = !isOver;
        textFieldController.clear();

        if (isOver) {
          isGameComplete = true;
          _showCompletionAnimation();
        }
      });
    } catch (error) {
      setState(() {
        isAnswerError = true;
      });
      logger.e('Error submitting answer: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.game.incarnation.concept == 'fill_in_the_blank'
            ? 'Fill in the Blank'
            : 'Count the Items'),
      ),
      body: Center(
        child: Column(
          children: [
            Column(
              children: [
                GameHeader(game: widget.game),
                if (!isGameComplete)
                  Form(
                    child: Column(children: <Widget>[
                      TextFormField(
                        controller: textFieldController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Answer',
                        ),
                        onChanged: (value) {
                          answer = value;
                        },
                        onFieldSubmitted: (value) async {
                          answer = value;
                          await submitAnswer(answer);
                        },
                      ),
                      if (isAnswerError)
                        const Text('Error submitting answer')
                      else if (hasAnsweredIncorrectly)
                        const Text('Wrong'),
                      ElevatedButton(
                        onPressed: () async {
                          await submitAnswer(answer);
                        },
                        child: const Text('Submit'),
                      )
                    ]),
                  ),
              ],
            ),
            if (isGameComplete)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Correct answer: $answer',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Congratulations! You have completed the game.',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go back!'),
            ),
          ],
        ),
      ),
    );
  }
}

bool checkGameCompletion(Map<String, dynamic> apiResponse) {
  if (apiResponse['included'] == null) return false;

  var included = apiResponse['included'] as List<dynamic>;

  for (var item in included) {
    if (item['type'] == 'games') {
      return item['attributes']['complete'] == true;
    }
  }

  return false;
}
