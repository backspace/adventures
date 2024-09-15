import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/run_header.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

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

class Answer {
  final String label;
  String value;
  AnswerSubmissionState state;
  String? errorMessage;

  Answer(
    this.label, {
    this.value = '',
    this.state = AnswerSubmissionState.unsubmitted,
    this.errorMessage,
  });
}

class FoodCourtFrenzyGameState extends State<FoodCourtFrenzyGame> {
  late List<Answer> answers;
  bool isGameComplete = false;
  Map<String, String> answerErrors = {};
  late Run currentGame;

  @override
  void initState() {
    super.initState();
    currentGame = widget.run;
    answers = currentGame.specification.answerLabels
            ?.map((label) => Answer(label))
            .toList() ??
        [];
  }

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
  }

  Future<void> submitAnswer(Answer answer) async {
    setState(() {
      answer.state = AnswerSubmissionState.submitting;
    });

    try {
      final response = await widget.dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {
              'submission': '${answer.label}|${answer.value}',
            },
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': currentGame.id},
              },
            },
          },
        },
      );

      setState(() {
        if (response.data['data']['attributes']['correct']) {
          answer.state = AnswerSubmissionState.correct;
          answer.errorMessage = null;
        } else {
          answer.state = AnswerSubmissionState.incorrect;
          answer.errorMessage = 'Incorrect answer. Try again.';
        }

        if (response.data['included'] != null) {
          final gameData = response.data['included'].firstWhere(
            (included) =>
                included['type'] == 'runs' && included['id'] == currentGame.id,
            orElse: () => null,
          );
          if (gameData != null) {
            currentGame = Run.fromJson(
                {'data': gameData, 'included': response.data['included']},
                existingSpecification: currentGame.specification);
          }
        }

        if (currentGame.correctAnswers == currentGame.totalAnswers) {
          isGameComplete = true;
          _showCompletionAnimation();
        }
      });
    } catch (e) {
      logger.e('Error submitting answer: $e');
      setState(() {
        answer.state = AnswerSubmissionState.error;
        answer.errorMessage = e.toString();
      });
    }
  }

  Widget _buildAnswerField(Answer answer) {
    return ListTile(
      title: Text(answer.label),
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
          RunHeader(run: currentGame),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Progress: ${currentGame.correctAnswers}/${currentGame.totalAnswers}',
            ),
          ),
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
