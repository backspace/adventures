import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/submission.dart';
import 'package:waydowntown/services/user_service.dart';
import 'package:waydowntown/widgets/losing_animation.dart';
import 'package:waydowntown/widgets/winning_animation.dart';

enum GameState {
  inProgress,
  won,
  lost,
}

mixin RunStateMixin<T extends StatefulWidget> on State<T> {
  late Run currentRun;
  GameState gameState = GameState.inProgress;

  Dio get dio;
  Run get initialRun;

  PhoenixChannel? channel;

  @override
  void initState() {
    super.initState();
    currentRun = initialRun;
  }

  bool get isGameComplete => gameState != GameState.inProgress;

  void _showCompletionAnimation() {
    if (gameState == GameState.won) {
      WinningAnimation.show(context);
    } else {
      LosingAnimation.show(context);
    }
  }

  Future<bool> submitSubmission(String submission, {String? answerId}) async {
    try {
      final response = await dio.post(
        '/waydowntown/submissions',
        data: {
          'data': {
            'type': 'submissions',
            'attributes': {
              'submission': submission,
            },
            'relationships': {
              'run': {
                'data': {'type': 'runs', 'id': currentRun.id},
              },
              if (answerId != null)
                'answer': {
                  'data': {'type': 'answers', 'id': answerId},
                },
            },
          },
        },
      );

      final bool isCorrect = response.data['data']['attributes']['correct'];

      if (response.data['included'] != null) {
        final runData = response.data['included'].firstWhere(
          (included) =>
              included['type'] == 'runs' && included['id'] == currentRun.id,
          orElse: () => null,
        );
        if (runData != null) {
          setState(() {
            currentRun = Run.fromJson(
                {'data': runData, 'included': response.data['included']},
                existingSpecification: currentRun.specification);
          });

          await checkForCompletion();
        }
      }

      return isCorrect;
    } catch (e) {
      talker.error('Error submitting answer: $e');
      rethrow;
    }
  }

  void initializeChannel(PhoenixChannel gameChannel) async {
    channel = gameChannel;
    channel!.messages.listen((message) async {
      if (message.event == const PhoenixChannelEvent.custom('run_update')) {
        setState(() {
          currentRun = Run.fromJson(message.payload!,
              existingSpecification: currentRun.specification);
        });

        await checkForCompletion();
      }
    });
  }

  Future<void> checkForCompletion() async {
    if (currentRun.isComplete &&
        gameState == GameState.inProgress &&
        currentRun.winnerSubmissionId != null) {
      final String? winnerSubmissionId = currentRun.winnerSubmissionId;
      final Submission winningSubmission = currentRun.submissions
          .firstWhere((submission) => submission.id == winnerSubmissionId);
      final bool isUserSubmission =
          winningSubmission.creatorId == await UserService.getUserId();

      gameState = isUserSubmission ? GameState.won : GameState.lost;
      _showCompletionAnimation();
    }
  }

  Future<Answer?> requestHint(String? answerId) async {
    try {
      final response = await dio.post('/waydowntown/reveals', data: {
        'data': {
          'type': 'reveals',
          'attributes': {},
          'relationships': {
            if (answerId != null)
              'answer': {
                'data': {'type': 'answers', 'id': answerId}
              },
            'run': {
              'data': {'type': 'runs', 'id': currentRun.id}
            }
          }
        }
      });

      if (response.data['included'] != null) {
        final runData = response.data['included'].firstWhere(
          (included) =>
              included['type'] == 'runs' && included['id'] == currentRun.id,
          orElse: () => null,
        );
        if (runData != null) {
          setState(() {
            currentRun = Run.fromJson(
                {'data': runData, 'included': response.data['included']},
                existingSpecification: currentRun.specification);
          });
        }
      }

      final includedAnswer = response.data['included']?.firstWhere(
        (included) => included['type'] == 'answers',
        orElse: () => null,
      );

      if (includedAnswer != null) {
        final answerIndex = currentRun.specification.answers
            ?.indexWhere((answer) => answer.id == includedAnswer?['id']);
        if (answerIndex != null) {
          final newAnswer = Answer.fromJson(includedAnswer);

          setState(() {
            currentRun.specification.answers?[answerIndex] = newAnswer;
          });

          return newAnswer;
        }
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final error = e.response?.data['errors'][0]['detail'];
        throw error ?? 'Failed to get hint';
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    channel?.leave();
    super.dispose();
  }
}
