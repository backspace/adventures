import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

mixin RunStateMixin<T extends StatefulWidget> on State<T> {
  late Run currentRun;
  bool isGameComplete = false;

  Dio get dio;
  Run get initialRun;

  PhoenixChannel? channel;

  @override
  void initState() {
    super.initState();
    currentRun = initialRun;
  }

  void _showCompletionAnimation() {
    CompletionAnimation.show(context);
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

            if (currentRun.isComplete) {
              isGameComplete = true;
              _showCompletionAnimation();
            }
          });
        }
      }

      return isCorrect;
    } catch (e) {
      talker.error('Error submitting answer: $e');
      rethrow;
    }
  }

  void initializeChannel(PhoenixChannel gameChannel) {
    channel = gameChannel;
    channel!.messages.listen((message) {
      if (message.event == const PhoenixChannelEvent.custom('run_update')) {
        setState(() {
          currentRun = Run.fromJson(message.payload!,
              existingSpecification: currentRun.specification);

          if (currentRun.isComplete && !isGameComplete) {
            isGameComplete = true;
            _showCompletionAnimation();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    channel?.leave();
    super.dispose();
  }
}
