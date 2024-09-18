import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:waydowntown/app.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/widgets/completion_animation.dart';

mixin RunStateMixin<T extends StatefulWidget> on State<T> {
  late Run currentRun;
  bool isGameComplete = false;

  Dio get dio;
  Run get initialRun;

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
      logger.e('Error submitting answer: $e');
      rethrow;
    }
  }
}
