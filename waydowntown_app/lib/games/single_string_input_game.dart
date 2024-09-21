import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/run_header.dart';

class SingleStringInputGame extends StatefulWidget {
  final Dio dio;
  final Run run;

  const SingleStringInputGame(
      {super.key, required this.dio, required this.run});

  @override
  SingleStringInputGameState createState() => SingleStringInputGameState();
}

class SingleStringInputGameState extends State<SingleStringInputGame>
    with RunStateMixin<SingleStringInputGame> {
  late Answer answer;

  String submission = 'submission';
  bool hasAnsweredIncorrectly = false;
  bool isOver = false;
  bool isRequestError = false;
  bool isAnswerError = false;
  TextEditingController textFieldController = TextEditingController();

  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  @override
  void initState() {
    super.initState();
    answer = initialRun.specification.answers![0];
  }

  Future<void> submitAnswer(String submission) async {
    try {
      final isCorrect = await submitSubmission(submission, answerId: answer.id);

      setState(() {
        if (isCorrect) {
          hasAnsweredIncorrectly = false;
        } else {
          hasAnsweredIncorrectly = true;
        }
        textFieldController.clear();
        isAnswerError = false;
      });
    } catch (e) {
      setState(() {
        isAnswerError = true;
        isRequestError = true;
      });
      talker.error('Error submitting answer: $e');
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RunHeader(run: currentRun),
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
                        await submitAnswer(submission);
                      },
                    ),
                  ),
                  if (isAnswerError)
                    const Text('Error submitting answer')
                  else if (hasAnsweredIncorrectly)
                    const Text('Wrong'),
                  ElevatedButton(
                    onPressed: () async {
                      await submitAnswer(submission);
                    },
                    child: const Text('Submit'),
                  )
                ]),
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
