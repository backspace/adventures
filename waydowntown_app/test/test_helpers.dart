import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:waydowntown/models/answer.dart';
import 'package:waydowntown/models/participation.dart';
import 'package:waydowntown/models/region.dart';
import 'package:waydowntown/models/run.dart';
import 'package:waydowntown/models/specification.dart';
import 'package:waydowntown/services/user_service.dart';

@GenerateNiceMocks([
  MockSpec<PhoenixSocket>(),
  MockSpec<PhoenixChannel>(),
  MockSpec<Push>(),
])
import 'test_helpers.mocks.dart';

class TestHelpers {
  static Future<void> setMockUser({
    String userId = 'user1',
    String email = 'user1@example.com',
    bool isAdmin = false,
    String accessToken = 'test_token',
    String renewalToken = 'test_renewal_token',
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    await UserService.setUserData(userId, email, isAdmin);
    await UserService.setTokens(accessToken, renewalToken);
  }

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

    final response = SubmissionResponse(
      submissionId: submissionId,
      submission: setup.submission,
      correct: setup.correct,
      runId: runId,
      correctSubmissions: setup.correctSubmissions,
      totalAnswers: setup.totalAnswers,
      isComplete: setup.isComplete,
    );

    final requestJson =
        generateSubmissionRequestJson(setup.submission, runId, setup.answerId);

    dioAdapter.onPost(
      setup.route,
      (server) =>
          server.reply(201, generateSubmissionResponseJson(response)),
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
    final runAttributes = {
      "correct_submissions": response.correctSubmissions,
      "total_answers": response.totalAnswers,
      "complete": response.isComplete,
      if (response.isComplete) "winner_submission_id": response.submissionId,
    };

    final included = [
      {
        "id": response.runId,
        "type": "runs",
        "attributes": runAttributes,
        if (response.isComplete)
          "relationships": {
            "submissions": {
              "data": [
                {"type": "submissions", "id": response.submissionId}
              ]
            }
          }
      },
      if (response.isComplete)
        {
          "id": response.submissionId,
          "type": "submissions",
          "attributes": {
            "submission": response.submission,
            "correct": response.correct,
            "inserted_at": DateTime.now().toUtc().toIso8601String(),
          },
          "relationships": {
            "creator": {
              "data": {"type": "users", "id": "user1"}
            }
          }
        }
    ];

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
          },
          if (response.isComplete)
            "creator": {
              "data": {"type": "users", "id": "user1"}
            }
        }
      },
      "included": included,
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
    Region? region,
    List<Participation>? participations,
  }) {
    return Run(
      id: '22261813-2171-453f-a669-db08edc70d6d',
      specification: Specification(
        id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
        placed: true,
        concept: concept,
        startDescription: start,
        taskDescription: description,
        answers: answers ??
            [
              const Answer(id: '1', label: 'Answer 1', hasHint: true),
              const Answer(id: '2', label: 'Answer 2', hasHint: true),
              const Answer(id: '3', label: 'Answer 3', hasHint: true),
            ],
        duration: durationSeconds,
        region: region ??
            Region(
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
      participations: participations ??
          [
            Participation(
              id: '1',
              userId: '1',
              userName: 'One',
              runId: 'run1',
              readyAt: null,
            ),
            Participation(
              id: '2',
              userId: '2',
              userName: 'Two',
              runId: 'run1',
              readyAt: null,
            ),
          ],
      submissions: [],
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

  static Map<String, dynamic> generateRunJson(Run run) {
    // Helper function to collect all parent regions
    List<Region> getAllRegions(Region region) {
      final regions = [region];
      var current = region.parentRegion;
      while (current != null) {
        regions.add(current);
        current = current.parentRegion;
      }
      return regions;
    }

    // Get all regions including parents
    final allRegions = run.specification.region != null
        ? getAllRegions(run.specification.region!)
        : <Region>[];

    return {
      "data": {
        "id": run.id,
        "type": "runs",
        "attributes": {
          "correct_submissions": run.correctSubmissions,
          "total_answers": run.totalAnswers,
          "started_at": run.startedAt?.toUtc().toIso8601String(),
          "description": run.taskDescription,
        },
        "relationships": {
          "specification": {
            "data": {"type": "specifications", "id": run.specification.id}
          },
          "participations": {
            "data": run.participations
                .map((p) => {
                      "type": "participations",
                      "id": p.id,
                    })
                .toList(),
          }
        }
      },
      "included": [
        {
          "id": run.specification.id,
          "type": "specifications",
          "attributes": {
            "concept": run.specification.concept,
            "placed": run.specification.placed,
            "start_description": run.specification.startDescription,
            "task_description": run.specification.taskDescription,
            "duration": run.specification.duration,
          },
          "relationships": {
            "region": run.specification.region != null
                ? {
                    "data": {
                      "type": "regions",
                      "id": run.specification.region!.id
                    }
                  }
                : {"data": null},
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
        // Include all regions (current and parents)
        ...allRegions.map((region) => {
              "id": region.id,
              "type": "regions",
              "attributes": {
                "name": region.name,
                "description": region.description,
                "latitude": region.latitude,
                "longitude": region.longitude,
              },
              "relationships": {
                "parent": region.parentRegion != null
                    ? {
                        "data": {
                          "type": "regions",
                          "id": region.parentRegion!.id
                        }
                      }
                    : {"data": null}
              }
            }),
        // Include answers
        ...run.specification.answers!.map((answer) => {
              "id": answer.id,
              "type": "answers",
              "attributes": {
                "label": answer.label,
              },
              "relationships": {
                "specification": {
                  "data": {"type": "specifications", "id": run.specification.id}
                }
              },
            }),
        // Include participations
        ...run.participations.map((p) => {
              "id": p.id,
              "type": "participations",
              "attributes": {
                "ready": p.readyAt != null,
              },
              "relationships": {
                "user": {
                  "data": {"type": "users", "id": p.userId}
                },
                "run": {
                  "data": {"type": "runs", "id": p.runId}
                }
              }
            }),
        ...run.participations.map((p) => {
              "id": p.userId,
              "type": "users",
              "attributes": {
                "name": p.userName,
              },
            }),
      ],
    };
  }

  static (MockPhoenixSocket, MockPhoenixChannel, MockPush) setupMockSocket() {
    final mockSocket = MockPhoenixSocket();
    final mockChannel = MockPhoenixChannel();
    final mockPush = MockPush();

    when(mockSocket.connect()).thenAnswer((_) async => mockSocket);
    when(mockSocket.addChannel(topic: anyNamed('topic')))
        .thenReturn(mockChannel);
    when(mockChannel.join()).thenReturn(mockPush);
    when(mockChannel.messages).thenAnswer((_) => const Stream.empty());

    return (mockSocket, mockChannel, mockPush);
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
