import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/specification.dart';

class TestHelpers {
  static void setupMockRunResponse(
    DioAdapter dioAdapter, {
    required String route,
    required Run run,
  }) {
    dioAdapter.onPost(
      route,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": run.id,
            "type": "runs",
            "attributes": {
              "correct_submissions": run.correctSubmissions,
              "total_answers": run.totalAnswers,
            },
            "relationships": {
              "specification": {
                "data": {"type": "specifications", "id": run.specification.id}
              }
            }
          },
          "included": [
            {
              "id": run.specification.id,
              "type": "specifications",
              "attributes": {
                "concept": run.specification.concept,
              },
              "relationships": {
                "region": {
                  "data": {
                    "type": "regions",
                    "id": run.specification.region!.id
                  }
                }
              },
            },
            {
              "id": run.specification.region!.id,
              "type": "regions",
              "attributes": {
                "name": run.specification.region!.name,
                "description": run.specification.region!.description
              },
              "relationships": {
                "parent": {"data": null}
              }
            }
          ],
        },
      ),
      data: {
        'data': {
          'type': 'runs',
          'attributes': {},
        },
      },
    );
  }

  static void setupMockSubmissionResponse(
      DioAdapter dioAdapter, SubmissionRequest setup) {
    final runId = setup.runId ?? "22261813-2171-453f-a669-db08edc70d6d";
    final submissionId =
        setup.submissionId ?? "48cf441e-ab98-4da6-8980-69fba3b4417d";

    final responseJson = generateSubmissionResponseJson(SubmissionResponse(
      submissionId: submissionId,
      submission: setup.submission,
      correct: setup.correct,
      runId: runId,
      correctSubmissions: setup.correctSubmissions,
      totalAnswers: setup.totalAnswers,
      isComplete: setup.isComplete,
    ));

    final requestJson =
        generateSubmissionRequestJson(setup.submission, runId, setup.answerId);

    dioAdapter.onPost(
      setup.route,
      (server) => server.reply(201, responseJson),
      data: requestJson,
    );
  }

  static void setupMockErrorResponse(DioAdapter dioAdapter, String route,
      {required dynamic data}) {
    dioAdapter.onPost(route, (server) => server.reply(500, {}), data: data);
  }

  static Map<String, dynamic> generateSubmissionRequestJson(
      String submission, String runId, String? answerId) {
    return {
      'data': {
        'type': 'submissions',
        'attributes': {
          'submission': submission,
        },
        'relationships': {
          'run': {
            'data': {'type': 'runs', 'id': runId}
          },
          ...(answerId == null)
              ? {}
              : {
                  'answer': {
                    'data': {'type': 'answers', 'id': answerId}
                  }
                }
        }
      }
    };
  }

  static Map<String, dynamic> generateSubmissionResponseJson(
      SubmissionResponse response) {
    return {
      "data": {
        "id": response.submissionId,
        "type": "submissions",
        "attributes": {
          "submission": response.submission,
          "correct": response.correct,
        },
        "relationships": {
          "run": {
            "data": {
              "type": "runs",
              "id": response.runId,
            }
          }
        }
      },
      "included": [
        {
          "id": response.runId,
          "type": "runs",
          "attributes": {
            "correct_submissions": response.correctSubmissions,
            "total_answers": response.totalAnswers,
            "complete": response.isComplete,
          }
        }
      ],
      "meta": {}
    };
  }

  static Run createMockRun({
    String concept = 'test_concept',
    String? description,
    String start = 'test_start',
    int correctAnswers = 0,
    int totalAnswers = 3,
    double? latitude,
    double? longitude,
    DateTime? startedAt,
    int? durationSeconds = 300,
    List<Answer>? answers,
  }) {
    return Run(
      id: '22261813-2171-453f-a669-db08edc70d6d',
      specification: Specification(
        id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
        placed: true,
        concept: concept,
        startDescription: start,
        answers: answers ??
            [
              const Answer(id: '1', label: 'Answer 1'),
              const Answer(id: '2', label: 'Answer 2'),
              const Answer(id: '3', label: 'Answer 3'),
            ],
        duration: durationSeconds,
        region: Region(
          id: '324fd8f9-cd25-48be-a761-b8680fa72737',
          name: 'Test Region',
          latitude: latitude,
          longitude: longitude,
          parentRegion: Region(
            id: '67cc2c5c-06c2-4e86-9aac-b575fc712862',
            name: 'Parent Region',
            description: null,
          ),
        ),
      ),
      correctSubmissions: correctAnswers,
      totalAnswers: totalAnswers,
      startedAt: startedAt,
      taskDescription: description,
    );
  }

  static void setupMockStartRunResponse(DioAdapter dioAdapter, Run run) {
    dioAdapter.onPost(
      '/waydowntown/runs/${run.id}/start',
      (server) => server.reply(
        200,
        {
          "data": {
            "id": run.id,
            "type": "runs",
            "attributes": {
              "correct_submissions": run.correctSubmissions,
              "total_answers": run.totalAnswers,
              "started_at": DateTime.now().toUtc().toIso8601String(),
              "description": run.taskDescription,
            },
            "relationships": {
              "specification": {
                "data": {"type": "specifications", "id": run.specification.id}
              }
            }
          },
          "included": [
            {
              "id": run.specification.id,
              "type": "specifications",
              "attributes": {
                "concept": run.specification.concept,
              },
              "relationships": {
                "region": {
                  "data": {
                    "type": "regions",
                    "id": run.specification.region!.id
                  }
                },
                "answers": {
                  "data": run.specification.answers!
                      .map((answer) => {
                            "id": answer.id,
                            "type": "answers",
                          })
                      .toList(),
                }
              },
            },
            {
              "id": run.specification.region!.id,
              "type": "regions",
              "attributes": {
                "name": run.specification.region!.name,
                "description": run.specification.region!.description
              },
              "relationships": {
                "parent": {"data": null}
              }
            },
            ...run.specification.answers!.map((answer) => {
                  "id": answer.id,
                  "type": "answers",
                  "attributes": {
                    "label": answer.label,
                  },
                  "relationships": {
                    "specification": {
                      "data": {
                        "type": "specifications",
                        "id": run.specification.id
                      }
                    }
                  },
                }),
          ],
        },
      ),
      data: {
        'data': {
          'type': 'runs',
          'id': run.id,
        },
      },
    );
  }
}

class SubmissionRequest {
  final String route;
  final String submission;
  final bool correct;
  final bool isComplete;
  final int correctSubmissions;
  final int totalAnswers;
  final String? runId;
  final String? answerId;
  final String? submissionId;

  SubmissionRequest({
    required this.route,
    required this.submission,
    required this.correct,
    this.isComplete = false,
    this.correctSubmissions = 0,
    this.totalAnswers = 3,
    this.runId,
    this.answerId,
    this.submissionId,
  });
}

class SubmissionResponse {
  final String submissionId;
  final String submission;
  final bool correct;
  final String runId;
  final int correctSubmissions;
  final int totalAnswers;
  final bool isComplete;

  SubmissionResponse({
    required this.submissionId,
    required this.submission,
    required this.correct,
    required this.runId,
    required this.correctSubmissions,
    required this.totalAnswers,
    this.isComplete = false,
  });
}
