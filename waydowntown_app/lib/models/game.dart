import 'package:waydowntown/models/incarnation.dart';

class Game {
  final String id;
  final Incarnation incarnation;
  final int correctAnswers;
  final int totalAnswers;

  Game({
    required this.id,
    required this.incarnation,
    required this.correctAnswers,
    required this.totalAnswers,
  });

  factory Game.fromJson(Map<String, dynamic> json,
      {Incarnation? existingIncarnation}) {
    final data = json['data'];
    final included = json['included'] as List<dynamic>?;

    Incarnation? incarnation = existingIncarnation;
    if (incarnation == null &&
        included != null &&
        data['relationships'] != null &&
        data['relationships']['incarnation'] != null) {
      final incarnationData = data['relationships']['incarnation']['data'];
      final incarnationJson = included.firstWhere(
        (item) =>
            item['type'] == 'incarnations' &&
            item['id'] == incarnationData['id'],
        orElse: () => null,
      );
      if (incarnationJson != null) {
        incarnation = Incarnation.fromJson(incarnationJson, included);
      }
    }

    return Game(
      id: data['id'],
      incarnation: incarnation ??
          (throw const FormatException('Game must have an incarnation')),
      correctAnswers: data['attributes']['correct_answers'] ?? 0,
      totalAnswers: data['attributes']['total_answers'] ?? 0,
    );
  }
}
