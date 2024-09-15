import 'package:http_mock_adapter/http_mock_adapter.dart';
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
              "correct_answers": run.correctAnswers,
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

  static Map<String, String> setupMockSubmissionResponse(
      DioAdapter dioAdapter, SubmissionRequest setup) {
    final runId = setup.runId ?? "22261813-2171-453f-a669-db08edc70d6d";
    final submissionId =
        setup.submissionId ?? "48cf441e-ab98-4da6-8980-69fba3b4417d";

    final responseJson = generateSubmissionResponseJson(SubmissionResponse(
      submissionId: submissionId,
      submission: setup.submission,
      correct: setup.correct,
      runId: runId,
      correctAnswers: setup.correctAnswers,
      totalAnswers: setup.totalAnswers,
      isComplete: setup.isComplete,
    ));

    final requestJson = generateSubmissionRequestJson(setup.submission, runId);

    if (setup.method == 'POST') {
      dioAdapter.onPost(
        setup.route,
        (server) => server.reply(201, responseJson),
        data: requestJson,
      );
    } else if (setup.method == 'PATCH') {
      dioAdapter.onPatch(
        setup.route,
        (server) => server.reply(200, responseJson),
        data: requestJson,
      );
    }

    return {'runId': runId, 'submissionId': submissionId};
  }

  static void setupMockErrorResponse(DioAdapter dioAdapter, String route,
      {required dynamic data}) {
    dioAdapter.onPost(route, (server) => server.reply(500, {}), data: data);
  }

  static Map<String, dynamic> generateSubmissionRequestJson(
      String submission, String runId) {
    return {
      'data': {
        'type': 'submissions',
        'attributes': {
          'submission': submission,
        },
        'relationships': {
          'run': {
            'data': {'type': 'runs', 'id': runId}
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
            "correct_answers": response.correctAnswers,
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
    List<String> answerLabels = const [
      'test_answer_label_1',
      'test_answer_label_2',
      'test_answer_label_3'
    ],
    int correctAnswers = 0,
    int totalAnswers = 3,
    double? latitude,
    double? longitude,
    DateTime? startedAt,
    int? durationSeconds = 300,
  }) {
    return Run(
      id: '22261813-2171-453f-a669-db08edc70d6d',
      specification: Specification(
        id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
        placed: true,
        concept: concept,
        start: start,
        answerLabels: answerLabels,
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
      correctAnswers: correctAnswers,
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
              "correct_answers": run.correctAnswers,
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
  final int correctAnswers;
  final int totalAnswers;
  final String method;
  final String? runId;
  final String? submissionId;

  SubmissionRequest({
    required this.route,
    required this.submission,
    required this.correct,
    this.isComplete = false,
    this.correctAnswers = 0,
    this.totalAnswers = 3,
    this.method = 'POST',
    this.runId,
    this.submissionId,
  });
}

class SubmissionResponse {
  final String submissionId;
  final String submission;
  final bool correct;
  final String runId;
  final int correctAnswers;
  final int totalAnswers;
  final bool isComplete;

  SubmissionResponse({
    required this.submissionId,
    required this.submission,
    required this.correct,
    required this.runId,
    required this.correctAnswers,
    required this.totalAnswers,
    this.isComplete = false,
  });
}
