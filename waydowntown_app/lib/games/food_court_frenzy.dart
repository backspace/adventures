import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/run_header.dart';

class FoodCourtFrenzyGame extends StatefulWidget {
  final Dio dio;
  final Run run;

  const FoodCourtFrenzyGame({super.key, required this.dio, required this.run});

  @override
  FoodCourtFrenzyGameState createState() => FoodCourtFrenzyGameState();
}

enum AnswerSubmissionState {
  unsubmitted,
  submitting,
  error,
  correct,
  incorrect
}

class SubmissionContainer {
  final Answer answer;
  String value;
  AnswerSubmissionState state;
  String? errorMessage;

  SubmissionContainer(
    this.answer, {
    this.value = '',
    this.state = AnswerSubmissionState.unsubmitted,
    this.errorMessage,
  });
}

class FoodCourtFrenzyGameState extends State<FoodCourtFrenzyGame>
    with RunStateMixin<FoodCourtFrenzyGame> {
  @override
  Dio get dio => widget.dio;

  @override
  Run get initialRun => widget.run;

  late List<SubmissionContainer> answers;
  Map<String, String> answerErrors = {};

  @override
  void initState() {
    super.initState();
    answers = currentRun.specification.answers
            ?.map((answer) => SubmissionContainer(answer))
            .toList() ??
        [];
  }

  Future<void> submitAnswer(SubmissionContainer answer) async {
    setState(() {
      answer.state = AnswerSubmissionState.submitting;
    });

    try {
      final isCorrect = await super
          .submitSubmission(answer.value, answerId: answer.answer.id);

      setState(() {
        if (isCorrect) {
          answer.state = AnswerSubmissionState.correct;
          answer.errorMessage = null;
        } else {
          answer.state = AnswerSubmissionState.incorrect;
          answer.errorMessage = 'Incorrect answer. Try again.';
        }
      });
    } catch (e) {
      setState(() {
        answer.state = AnswerSubmissionState.error;
        answer.errorMessage = e.toString();
      });
    }
  }

  Widget _buildAnswerField(SubmissionContainer answer) {
    return ListTile(
      title: Text(answer.answer.label!),
      subtitle: answer.state == AnswerSubmissionState.correct
          ? Text(answer.value, style: const TextStyle(color: Colors.green))
          : TextField(
              onChanged: (value) {
                setState(() {
                  answer.value = value;
                  if (answer.state == AnswerSubmissionState.incorrect) {
                    answer.state = AnswerSubmissionState.unsubmitted;
                    answer.errorMessage = null;
                  }
                });
              },
              onSubmitted: (_) => submitAnswer(answer),
              decoration: InputDecoration(
                errorText: answer.errorMessage,
                errorStyle: TextStyle(
                  color: answer.state == AnswerSubmissionState.incorrect
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
            ),
      trailing: answer.state == AnswerSubmissionState.correct
          ? const Icon(Icons.check_circle, color: Colors.green)
          : IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => submitAnswer(answer),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Court Frenzy'),
      ),
      body: Column(
        children: [
          RunHeader(run: currentRun),
          if (isGameComplete)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Congratulations! You have completed the game.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: answers.length,
              itemBuilder: (context, index) =>
                  _buildAnswerField(answers[index]),
            ),
          ),
        ],
      ),
    );
  }
}
