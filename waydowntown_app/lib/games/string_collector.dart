import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/game_header.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

class StringCollectorGame extends StatefulWidget {
  final Dio dio;
  final Game game;

  const StringCollectorGame({super.key, required this.dio, required this.game});

  @override
  StringCollectorGameState createState() => StringCollectorGameState();
}

enum StringSubmissionState {
  unsubmitted,
  submitting,
  error,
  correct,
  incorrect
}

class SubmittedString {
  final String value;
  StringSubmissionState state;

  SubmittedString(this.value, {this.state = StringSubmissionState.unsubmitted});
}

class StringCollectorGameState extends State<StringCollectorGame> {
  List<SubmittedString> submittedStrings = [];
  bool isGameComplete = false;
  TextEditingController textFieldController = TextEditingController();
  Map<String, String> stringErrors = {};
  late FocusNode _focusNode;

  late Game currentGame;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();
    currentGame = widget.game;
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
  }

  Future<void> submitString(String value) async {
    setState(() {
      textFieldController.clear();
    });

    try {
      final response = await widget.dio.post(
        '/waydowntown/answers',
        data: {
          'data': {
            'type': 'answers',
            'attributes': {
              'answer': value,
            },
            'relationships': {
              'game': {
                'data': {'type': 'games', 'id': currentGame.id},
              },
            },
          },
        },
      );

      final submittedString = SubmittedString(value);
      setState(() {
        if (response.data['data']['attributes']['correct']) {
          submittedString.state = StringSubmissionState.correct;
        } else {
          submittedString.state = StringSubmissionState.incorrect;
        }

        _addString(submittedString);

        if (response.data['included'] != null) {
          final gameData = response.data['included'].firstWhere(
            (included) =>
                included['type'] == 'games' && included['id'] == currentGame.id,
            orElse: () => null,
          );
          if (gameData != null) {
            currentGame = Game.fromJson(
                {'data': gameData, 'included': response.data['included']},
                existingIncarnation: currentGame.incarnation);
          }
        }

        if (currentGame.correctAnswers == currentGame.totalAnswers) {
          isGameComplete = true;
          _showCompletionAnimation();
        }
      });

      _focusNode.requestFocus();
    } catch (e) {
      logger.e('Error submitting string: $e');
      final submittedString =
          SubmittedString(value, state: StringSubmissionState.error);
      setState(() {
        _addString(submittedString);
        stringErrors[value] = e.toString();
      });
    }
  }

  void _addString(SubmittedString string) {
    setState(() {
      submittedStrings.insert(0, string);
      _listKey.currentState?.insertItem(0);
    });
  }

  Widget _getIconForState(StringSubmissionState state, String value) {
    switch (state) {
      case StringSubmissionState.submitting:
        return const Icon(Icons.hourglass_empty,
            color: Colors.blue, size: 24.0);
      case StringSubmissionState.error:
        return IconButton(
          icon: const Icon(Icons.info, color: Colors.red, size: 24.0),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text(stringErrors[value] ?? 'Unknown error'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      case StringSubmissionState.correct:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24.0);
      case StringSubmissionState.incorrect:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24.0);
      default:
        return const Icon(Icons.radio_button_unchecked,
            color: Colors.grey, size: 24.0);
    }
  }

  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    SubmittedString submittedString = submittedStrings[index];
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      )),
      child: ListTile(
        title: Text(submittedString.value),
        leading: _getIconForState(submittedString.state, submittedString.value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('String Collector'),
      ),
      body: Column(
        children: [
          GameHeader(game: currentGame),
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
            )
          else
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: textFieldController,
                    focusNode: _focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Enter a string',
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        submitString(value);
                      }
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (textFieldController.text.isNotEmpty) {
                      submitString(textFieldController.text);
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: submittedStrings.length,
              itemBuilder: (context, index, animation) {
                return _buildItem(context, index, animation);
              },
            ),
          ),
        ],
      ),
    );
  }
}
