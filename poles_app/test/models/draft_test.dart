import 'package:flutter_test/flutter_test.dart';
import 'package:poles/models/draft.dart';

void main() {
  group('DraftPole.fromJson', () {
    test('parses status and accuracy', () {
      final p = DraftPole.fromJson({
        'id': 'p1',
        'barcode': 'POLE-001',
        'label': 'Forks',
        'latitude': 49.89,
        'longitude': -97.13,
        'notes': 'by the bus stop',
        'accuracy_m': 8.4,
        'status': 'draft',
        'creator_id': 'u1',
        'inserted_at': '2026-04-30T12:00:00Z',
      });

      expect(p.status, DraftStatus.draft);
      expect(p.accuracyM, 8.4);
      expect(p.notes, 'by the bus stop');
    });

    test('defaults to draft when status is missing', () {
      final p = DraftPole.fromJson({
        'id': 'p1',
        'barcode': 'b',
        'label': null,
        'latitude': 49.0,
        'longitude': -97.0,
        'notes': null,
        'accuracy_m': null,
        'creator_id': null,
        'inserted_at': null,
      });
      expect(p.status, DraftStatus.draft);
      expect(p.accuracyM, isNull);
    });
  });

  group('DraftPuzzlet.fromJson', () {
    test('handles unassigned puzzlet (pole_id null)', () {
      final p = DraftPuzzlet.fromJson({
        'id': 'pz1',
        'instructions': 'What colour?',
        'answer': 'red',
        'difficulty': 3,
        'status': 'validated',
        'pole_id': null,
        'creator_id': 'u1',
        'inserted_at': '2026-04-30T12:00:00Z',
      });
      expect(p.poleId, isNull);
      expect(p.status, DraftStatus.validated);
      expect(p.latitude, isNull);
    });

    test('parses location fields when present', () {
      final p = DraftPuzzlet.fromJson({
        'id': 'pz1',
        'instructions': 'i',
        'answer': 'a',
        'difficulty': 2,
        'status': 'draft',
        'pole_id': null,
        'creator_id': null,
        'latitude': 49.89,
        'longitude': -97.13,
        'accuracy_m': 5.5,
        'inserted_at': null,
      });
      expect(p.latitude, 49.89);
      expect(p.longitude, -97.13);
      expect(p.accuracyM, 5.5);
    });
  });

  group('MyDrafts.fromJson', () {
    test('parses both lists', () {
      final m = MyDrafts.fromJson({
        'poles': [
          {
            'id': 'p1',
            'barcode': 'b',
            'label': null,
            'latitude': 49.0,
            'longitude': -97.0,
            'notes': null,
            'accuracy_m': null,
            'status': 'draft',
            'creator_id': null,
            'inserted_at': null,
          }
        ],
        'puzzlets': [
          {
            'id': 'pz1',
            'instructions': 'i',
            'answer': 'a',
            'difficulty': 1,
            'status': 'draft',
            'pole_id': null,
            'creator_id': null,
            'inserted_at': null,
          }
        ],
      });
      expect(m.poles, hasLength(1));
      expect(m.puzzlets, hasLength(1));
    });
  });
}
