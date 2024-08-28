import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:waydowntown/models/game.dart';
import 'package:waydowntown/models/incarnation.dart';
import 'package:waydowntown/models/region.dart';

class TestHelpers {
  static void setupMockGameResponse(
    DioAdapter dioAdapter, {
    required String route,
    required Game game,
  }) {
    dioAdapter.onPost(
      route,
      (server) => server.reply(
        201,
        {
          "data": {
            "id": game.id,
            "type": "games",
            "attributes": {
              "correct_answers": game.correctAnswers,
              "total_answers": game.totalAnswers,
            },
            "relationships": {
              "incarnation": {
                "data": {"type": "incarnations", "id": game.incarnation.id}
              }
            }
          },
          "included": [
            {
              "id": game.incarnation.id,
              "type": "incarnations",
              "attributes": {
                "concept": game.incarnation.concept,
                "mask": game.incarnation.mask
              },
              "relationships": {
                "region": {
                  "data": {"type": "regions", "id": game.incarnation.region!.id}
                }
              },
            },
            {
              "id": game.incarnation.region!.id,
              "type": "regions",
              "attributes": {
                "name": game.incarnation.region!.name,
                "description": game.incarnation.region!.description
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
          'type': 'games',
          'attributes': {},
        },
      },
    );
  }

  static Map<String, String> setupMockAnswerResponse(
      DioAdapter dioAdapter, AnswerRequest setup) {
    final gameId = setup.gameId ?? "22261813-2171-453f-a669-db08edc70d6d";
    final answerId = setup.answerId ?? "48cf441e-ab98-4da6-8980-69fba3b4417d";

    final responseJson = generateAnswerResponseJson(AnswerResponse(
      answerId: answerId,
      answer: setup.answer,
      correct: setup.correct,
      gameId: gameId,
      correctAnswers: setup.correctAnswers,
      totalAnswers: setup.totalAnswers,
      isComplete: setup.isComplete,
    ));

    final requestJson = generateAnswerRequestJson(setup.answer, gameId);

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

    return {'gameId': gameId, 'answerId': answerId};
  }

  static void setupMockErrorResponse(DioAdapter dioAdapter, String route,
      {required dynamic data}) {
    dioAdapter.onPost(route, (server) => server.reply(500, {}), data: data);
  }

  static Map<String, dynamic> generateAnswerRequestJson(
      String answer, String gameId) {
    return {
      'data': {
        'type': 'answers',
        'attributes': {
          'answer': answer,
        },
        'relationships': {
          'game': {
            'data': {'type': 'games', 'id': gameId}
          }
        }
      }
    };
  }

  static Map<String, dynamic> generateAnswerResponseJson(
      AnswerResponse response) {
    return {
      "data": {
        "id": response.answerId,
        "type": "answers",
        "attributes": {
          "answer": response.answer,
          "correct": response.correct,
        },
        "relationships": {
          "game": {
            "data": {
              "type": "games",
              "id": response.gameId,
            }
          }
        }
      },
      "included": [
        {
          "id": response.gameId,
          "type": "games",
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

  static Game createMockGame(
      {String concept = 'test_concept',
      String mask = 'test_mask',
      String start = 'test_start',
      int correctAnswers = 0,
      int totalAnswers = 3}) {
    return Game(
      id: '22261813-2171-453f-a669-db08edc70d6d',
      incarnation: Incarnation(
        id: '0091eb84-85c8-4e63-962b-39e1a19d2781',
        placed: true,
        concept: concept,
        mask: mask,
        start: start,
        region: Region(
          id: '324fd8f9-cd25-48be-a761-b8680fa72737',
          name: 'Test Region',
          description: null,
          parentRegion: Region(
            id: '67cc2c5c-06c2-4e86-9aac-b575fc712862',
            name: 'Parent Region',
            description: null,
          ),
        ),
      ),
      correctAnswers: correctAnswers,
      totalAnswers: totalAnswers,
    );
  }
}

class AnswerRequest {
  final String route;
  final String answer;
  final bool correct;
  final bool isComplete;
  final int correctAnswers;
  final int totalAnswers;
  final String method;
  final String? gameId;
  final String? answerId;

  AnswerRequest({
    required this.route,
    required this.answer,
    required this.correct,
    this.isComplete = false,
    this.correctAnswers = 0,
    this.totalAnswers = 3,
    this.method = 'POST',
    this.gameId,
    this.answerId,
  });
}

class AnswerResponse {
  final String answerId;
  final String answer;
  final bool correct;
  final String gameId;
  final int correctAnswers;
  final int totalAnswers;
  final bool isComplete;

  AnswerResponse({
    required this.answerId,
    required this.answer,
    required this.correct,
    required this.gameId,
    required this.correctAnswers,
    required this.totalAnswers,
    this.isComplete = false,
  });
}
