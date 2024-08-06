import 'package:waydowntown/models/incarnation.dart';

class Game {
  final String id;
  final Incarnation incarnation;

  Game({required this.id, required this.incarnation});

  factory Game.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final included = json['included'] as List<dynamic>;

    if (data['relationships'] == null ||
        data['relationships']['incarnation'] == null) {
      throw const FormatException('Game must have an incarnation');
    }

    final incarnationData = data['relationships']['incarnation']['data'];
    final incarnationJson = included.firstWhere(
      (item) =>
          item['type'] == 'incarnations' && item['id'] == incarnationData['id'],
      orElse: () =>
          throw const FormatException('Incarnation not found in included data'),
    );

    return Game(
        id: data['id'],
        incarnation: Incarnation.fromJson(incarnationJson, included));
  }
}
