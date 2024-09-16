import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/run_header.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

class SingleStringInputGame extends StatefulWidget {
  final Dio dio;
  final Run run;

  const SingleStringInputGame(
      {super.key, required this.dio, required this.run});

  @override
  SingleStringInputGameState createState() => SingleStringInputGameState();
}

class SingleStringInputGameState extends State<SingleStringInputGame> {
  late Answer answer;

  String submission = 'submission';
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
    answer = widget.run.specification.answers![0];
  }

  Future<void> submitSubmission(String submission) async {
    try {
      final response = await widget.dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {
              'submission': submission,
            },
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': widget.run.id},
              },
              'answer': {
                'data': {'type': 'answers', 'id': answer.id},
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
        title: Text(widget.run.specification.concept == 'fill_in_the_blank'
            ? 'Fill in the Blank'
            : 'Count the Items'),
      ),
      body: Center(
        child: Column(
          children: [
            Column(
              children: [
                RunHeader(run: widget.run),
                if (!isGameComplete)
                  Form(
                    child: Column(children: <Widget>[
                      ListTile(
                          title: Text(answer.label!),
                          subtitle: TextFormField(
                            controller: textFieldController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Answer',
                            ),
                            onChanged: (value) {
                              submission = value;
                            },
                            onFieldSubmitted: (value) async {
                              submission = value;
                              await submitSubmission(submission);
                            },
                          )),
                      if (isAnswerError)
                        const Text('Error submitting answer')
                      else if (hasAnsweredIncorrectly)
                        const Text('Wrong'),
                      ElevatedButton(
                        onPressed: () async {
                          await submitSubmission(submission);
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
                      'Correct answer: $submission',
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
    if (item['type'] == 'runs') {
      return item['attributes']['complete'] == true;
    }
  }

  return false;
}
