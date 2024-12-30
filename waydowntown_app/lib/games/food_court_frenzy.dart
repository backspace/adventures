import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:waydowntown/mixins/run_state_mixin.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/run_header.dart';

class FoodCourtFrenzyGame extends StatefulWidget {
  final Dio dio;
  final Run run;
  final PhoenixChannel channel;

  const FoodCourtFrenzyGame({
    super.key,
    required this.dio,
    required this.run,
    required this.channel,
  });

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
  String? hint;
  bool isLoadingHint = false;

  SubmissionContainer(
    this.answer, {
    this.value = '',
    this.state = AnswerSubmissionState.unsubmitted,
    this.errorMessage,
    this.hint,
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
    initializeChannel(widget.channel);
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

  Future<void> _requestHint(SubmissionContainer answer) async {
    if (answer.hint != null || answer.isLoadingHint) return;

    setState(() {
      answer.isLoadingHint = true;
      answer.errorMessage = null;
    });

    try {
      final answerData = await requestHint(answer.answer.id);
      setState(() {
        answer.hint = answerData?.label;
        answer.isLoadingHint = false;
      });
    } catch (e) {
      setState(() {
        answer.errorMessage = e.toString();
        answer.isLoadingHint = false;
      });
    }
  }

  Widget _buildAnswerField(SubmissionContainer answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Row(
            children: [
              Expanded(child: Text(answer.answer.label!)),
              if (answer.hint == null &&
                  answer.state != AnswerSubmissionState.correct)
                IconButton(
                  icon: answer.isLoadingHint
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lightbulb_outline),
                  onPressed: () => _requestHint(answer),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (answer.hint != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Hint: ${answer.hint}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
                ),
              answer.state == AnswerSubmissionState.correct
                  ? Text(answer.value,
                      style: const TextStyle(color: Colors.green))
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
            ],
          ),
          trailing: answer.state == AnswerSubmissionState.correct
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => submitAnswer(answer),
                ),
        ),
      ],
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
