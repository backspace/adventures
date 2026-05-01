import 'package:flutter_test/flutter_test.dart';
import 'package:poles/models/pole.dart';

void main() {
  group('Pole.fromJson', () {
    test('parses all fields', () {
      final pole = Pole.fromJson({
        'id': 'p1',
        'barcode': 'POLE-001',
        'label': 'The Forks',
        'latitude': 49.8889,
        'longitude': -97.1303,
        'current_owner_team_id': 't1',
        'locked': false,
      });

      expect(pole.id, 'p1');
      expect(pole.barcode, 'POLE-001');
      expect(pole.label, 'The Forks');
      expect(pole.latitude, 49.8889);
      expect(pole.longitude, -97.1303);
      expect(pole.currentOwnerTeamId, 't1');
      expect(pole.locked, isFalse);
    });

    test('tolerates null label and owner', () {
      final pole = Pole.fromJson({
        'id': 'p1',
        'barcode': 'POLE-001',
        'label': null,
        'latitude': 49.0,
        'longitude': -97.0,
        'current_owner_team_id': null,
        'locked': false,
      });

      expect(pole.label, isNull);
      expect(pole.currentOwnerTeamId, isNull);
    });

    test('coerces integer latitude/longitude', () {
      final pole = Pole.fromJson({
        'id': 'p1',
        'barcode': 'b',
        'label': null,
        'latitude': 49,
        'longitude': -97,
        'current_owner_team_id': null,
        'locked': false,
      });

      expect(pole.latitude, 49.0);
      expect(pole.longitude, -97.0);
    });
  });

  group('Puzzlet.fromJson', () {
    test('parses previous_wrong_answers when present', () {
      final p = Puzzlet.fromJson({
        'id': 'pz1',
        'instructions': 'What year?',
        'difficulty': 3,
        'attempts_remaining': 2,
        'previous_wrong_answers': ['1989', '88'],
      });

      expect(p.attemptsRemaining, 2);
      expect(p.previousWrongAnswers, ['1989', '88']);
    });

    test('defaults previous_wrong_answers to empty list when absent', () {
      final p = Puzzlet.fromJson({
        'id': 'pz1',
        'instructions': 'What year?',
        'difficulty': 3,
        'attempts_remaining': 3,
      });

      expect(p.previousWrongAnswers, isEmpty);
    });
  });

  group('ScanResult.fromJson', () {
    test('handles null active_puzzlet', () {
      final r = ScanResult.fromJson({
        'pole': {
          'id': 'p1',
          'barcode': 'b',
          'label': null,
          'latitude': 49.0,
          'longitude': -97.0,
          'current_owner_team_id': null,
          'locked': true,
        },
        'active_puzzlet': null,
      });

      expect(r.pole.locked, isTrue);
      expect(r.activePuzzlet, isNull);
    });

    test('parses pole and active_puzzlet together', () {
      final r = ScanResult.fromJson({
        'pole': {
          'id': 'p1',
          'barcode': 'b',
          'label': 'Lab',
          'latitude': 49.0,
          'longitude': -97.0,
          'current_owner_team_id': null,
          'locked': false,
        },
        'active_puzzlet': {
          'id': 'pz1',
          'instructions': 'Solve me',
          'difficulty': 1,
          'attempts_remaining': 3,
          'previous_wrong_answers': [],
        },
      });

      expect(r.pole.label, 'Lab');
      expect(r.activePuzzlet, isNotNull);
      expect(r.activePuzzlet!.id, 'pz1');
    });
  });
}
