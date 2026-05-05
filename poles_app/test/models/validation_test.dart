import 'package:flutter_test/flutter_test.dart';
import 'package:poles/models/validation.dart';

void main() {
  group('PoleValidationModel.fromJson', () {
    test('parses status, pole, and comments', () {
      final v = PoleValidationModel.fromJson({
        'id': 'v1',
        'status': 'in_progress',
        'overall_notes': null,
        'pole_id': 'p1',
        'validator_id': 'u1',
        'assigned_by_id': 's1',
        'pole': {
          'id': 'p1',
          'barcode': 'POLE-001',
          'label': 'Forks',
          'latitude': 49.89,
          'longitude': -97.13,
          'notes': null,
          'status': 'in_review',
        },
        'comments': [
          {
            'id': 'c1',
            'field': 'label',
            'comment': 'looks off',
            'suggested_value': 'The Forks',
            'status': 'pending',
          }
        ],
      });

      expect(v.status, ValidationStatus.inProgress);
      expect(v.pole?.barcode, 'POLE-001');
      expect(v.comments.single.field, 'label');
      expect(v.comments.single.status, CommentStatus.pending);
    });
  });

  group('PuzzletValidationModel.fromJson', () {
    test('parses puzzlet without location', () {
      final v = PuzzletValidationModel.fromJson({
        'id': 'v1',
        'status': 'submitted',
        'overall_notes': null,
        'puzzlet_id': 'pz1',
        'validator_id': 'u1',
        'assigned_by_id': 's1',
        'puzzlet': {
          'id': 'pz1',
          'instructions': 'go here',
          'answer': 'cat',
          'difficulty': 5,
          'status': 'in_review',
          'latitude': null,
          'longitude': null,
        },
        'comments': [],
      });

      expect(v.status, ValidationStatus.submitted);
      expect(v.puzzlet?.latitude, isNull);
      expect(v.comments, isEmpty);
    });
  });

  group('MyValidations.fromJson', () {
    test('parses both arms', () {
      final m = MyValidations.fromJson({
        'pole_validations': [],
        'puzzlet_validations': [],
      });
      expect(m.poleValidations, isEmpty);
      expect(m.puzzletValidations, isEmpty);
    });
  });

  group('DashboardCounts.fromJson', () {
    test('parses status maps', () {
      final c = DashboardCounts.fromJson({
        'poles': {'draft': 3, 'validated': 1},
        'puzzlets': {'draft': 5},
        'pole_validations_submitted': 2,
        'puzzlet_validations_submitted': 0,
      });
      expect(c.poles['draft'], 3);
      expect(c.puzzlets['draft'], 5);
      expect(c.poleValidationsSubmitted, 2);
    });
  });
}
