import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:poles/api/poles_api.dart';
import 'package:poles/models/pole.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late PolesApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.invalid'));
    adapter = DioAdapter(dio: dio);
    api = PolesApi(dio);
  });

  Map<String, dynamic> polePayload({bool locked = false, String? owner}) => {
        'id': 'p1',
        'barcode': 'POLE-004',
        'label': 'Esplanade Riel',
        'latitude': 49.8898,
        'longitude': -97.1267,
        'current_owner_team_id': owner,
        'locked': locked,
      };

  Map<String, dynamic> puzzletPayload({int remaining = 3, List<String> wrong = const []}) => {
        'id': 'pz1',
        'instructions': 'Which river?',
        'difficulty': 1,
        'attempts_remaining': remaining,
        'previous_wrong_answers': wrong,
      };

  group('scan', () {
    test('returns ScanFound on 200', () async {
      adapter.onGet(
        '/poles/poles/POLE-004',
        (server) => server.reply(200, {
          'pole': polePayload(),
          'active_puzzlet': puzzletPayload(),
        }),
      );

      final outcome = await api.scan('POLE-004');
      expect(outcome, isA<ScanFound>());
      final found = outcome as ScanFound;
      expect(found.result.pole.barcode, 'POLE-004');
      expect(found.result.activePuzzlet?.id, 'pz1');
    });

    test('returns ScanUnknownBarcode on 404', () async {
      adapter.onGet(
        '/poles/poles/NOPE',
        (server) => server.reply(404, {
          'error': {'code': 'pole_not_found', 'detail': 'No pole with that barcode.'}
        }),
      );

      final outcome = await api.scan('NOPE');
      expect(outcome, isA<ScanUnknownBarcode>());
    });

    test('returns ScanAlreadyOwner on 409 already_owner', () async {
      adapter.onGet(
        '/poles/poles/POLE-004',
        (server) => server.reply(409, {
          'error': {'code': 'already_owner', 'detail': '...'},
          'pole': polePayload(owner: 't1'),
        }),
      );

      final outcome = await api.scan('POLE-004');
      expect(outcome, isA<ScanAlreadyOwner>());
      expect((outcome as ScanAlreadyOwner).pole.label, 'Esplanade Riel');
    });

    test('returns ScanTeamLockedOut on 423 team_locked_out', () async {
      adapter.onGet(
        '/poles/poles/POLE-004',
        (server) => server.reply(423, {
          'error': {'code': 'team_locked_out', 'detail': '...'},
          'pole': polePayload(),
        }),
      );

      final outcome = await api.scan('POLE-004');
      expect(outcome, isA<ScanTeamLockedOut>());
    });

    test('rethrows on network/5xx', () async {
      adapter.onGet(
        '/poles/poles/POLE-004',
        (server) => server.reply(500, {'error': 'boom'}),
      );

      expect(() => api.scan('POLE-004'), throwsA(isA<DioException>()));
    });
  });

  group('submitAnswer', () {
    test('returns AttemptCorrect on correct answer', () async {
      adapter.onPost(
        '/poles/puzzlets/pz1/attempts',
        (server) => server.reply(200, {
          'correct': true,
          'captured': true,
          'capture': {'id': 'c1', 'team_id': 't1', 'puzzlet_id': 'pz1'},
          'pole': {'id': 'p1', 'locked': false, 'current_owner_team_id': 't1'},
        }),
        data: {'answer': 'Red'},
      );

      final outcome = await api.submitAnswer('pz1', 'Red');
      expect(outcome, isA<AttemptCorrect>());
      final correct = outcome as AttemptCorrect;
      expect(correct.captureTeamId, 't1');
      expect(correct.poleLocked, isFalse);
    });

    test('returns AttemptIncorrect with previous wrong answers', () async {
      adapter.onPost(
        '/poles/puzzlets/pz1/attempts',
        (server) => server.reply(200, {
          'correct': false,
          'attempts_remaining': 2,
          'previous_wrong_answers': ['blue'],
        }),
        data: {'answer': 'blue'},
      );

      final outcome = await api.submitAnswer('pz1', 'blue');
      expect(outcome, isA<AttemptIncorrect>());
      final incorrect = outcome as AttemptIncorrect;
      expect(incorrect.attemptsRemaining, 2);
      expect(incorrect.previousWrongAnswers, ['blue']);
    });

    test('returns AttemptLockedOut on 423 locked_out', () async {
      adapter.onPost(
        '/poles/puzzlets/pz1/attempts',
        (server) => server.reply(423, {
          'error': {'code': 'locked_out', 'detail': '...'},
        }),
        data: {'answer': 'x'},
      );

      final outcome = await api.submitAnswer('pz1', 'x');
      expect(outcome, isA<AttemptLockedOut>());
    });

    test('returns AttemptAlreadyOwner on 409 already_owner', () async {
      adapter.onPost(
        '/poles/puzzlets/pz1/attempts',
        (server) => server.reply(409, {
          'error': {'code': 'already_owner', 'detail': '...'},
        }),
        data: {'answer': 'x'},
      );

      final outcome = await api.submitAnswer('pz1', 'x');
      expect(outcome, isA<AttemptAlreadyOwner>());
    });

    test('returns AttemptAlreadyCaptured on 409 already_captured', () async {
      adapter.onPost(
        '/poles/puzzlets/pz1/attempts',
        (server) => server.reply(409, {
          'error': {'code': 'already_captured', 'detail': '...'},
        }),
        data: {'answer': 'x'},
      );

      final outcome = await api.submitAnswer('pz1', 'x');
      expect(outcome, isA<AttemptAlreadyCaptured>());
    });
  });

  group('drafts', () {
    test('createDraftPole posts the expected fields', () async {
      adapter.onPost(
        '/poles/drafts/poles',
        (server) => server.reply(201, {
          'id': 'p1',
          'barcode': 'POLE-X',
          'label': 'Test',
          'latitude': 49.89,
          'longitude': -97.13,
          'notes': null,
          'accuracy_m': 6.4,
          'status': 'draft',
          'creator_id': 'u1',
          'inserted_at': '2026-04-30T00:00:00Z',
        }),
        data: {
          'barcode': 'POLE-X',
          'latitude': 49.89,
          'longitude': -97.13,
          'label': 'Test',
          'accuracy_m': 6.4,
        },
      );

      final pole = await api.createDraftPole(
        barcode: 'POLE-X',
        latitude: 49.89,
        longitude: -97.13,
        label: 'Test',
        accuracyM: 6.4,
      );

      expect(pole.barcode, 'POLE-X');
      expect(pole.accuracyM, 6.4);
    });

    test('createDraftPuzzlet posts location fields', () async {
      adapter.onPost(
        '/poles/drafts/puzzlets',
        (server) => server.reply(201, {
          'id': 'pz1',
          'instructions': 'What?',
          'answer': 'cat',
          'difficulty': 4,
          'status': 'draft',
          'pole_id': null,
          'creator_id': 'u1',
          'latitude': 49.89,
          'longitude': -97.13,
          'accuracy_m': 6.4,
          'inserted_at': '2026-04-30T00:00:00Z',
        }),
        data: {
          'instructions': 'What?',
          'answer': 'cat',
          'difficulty': 4,
          'latitude': 49.89,
          'longitude': -97.13,
          'accuracy_m': 6.4,
        },
      );

      final puzzlet = await api.createDraftPuzzlet(
        instructions: 'What?',
        answer: 'cat',
        difficulty: 4,
        latitude: 49.89,
        longitude: -97.13,
        accuracyM: 6.4,
      );

      expect(puzzlet.id, 'pz1');
      expect(puzzlet.poleId, isNull);
      expect(puzzlet.latitude, 49.89);
      expect(puzzlet.accuracyM, 6.4);
    });

    test('updateDraftPole patches editable fields', () async {
      adapter.onPatch(
        '/poles/drafts/poles/p1',
        (server) => server.reply(200, {
          'id': 'p1',
          'barcode': 'b',
          'label': 'edited',
          'latitude': 49.89,
          'longitude': -97.13,
          'notes': 'updated note',
          'accuracy_m': 6.0,
          'status': 'draft',
          'creator_id': 'u1',
          'inserted_at': null,
        }),
        data: {'label': 'edited', 'notes': 'updated note'},
      );

      final pole = await api.updateDraftPole('p1', label: 'edited', notes: 'updated note');
      expect(pole.label, 'edited');
      expect(pole.notes, 'updated note');
    });

    test('updateDraftPuzzlet patches difficulty and answer', () async {
      adapter.onPatch(
        '/poles/drafts/puzzlets/pz1',
        (server) => server.reply(200, {
          'id': 'pz1',
          'instructions': 'i',
          'answer': 'cat',
          'difficulty': 7,
          'status': 'draft',
          'pole_id': null,
          'creator_id': 'u1',
          'latitude': null,
          'longitude': null,
          'accuracy_m': null,
          'inserted_at': null,
        }),
        data: {'answer': 'cat', 'difficulty': 7},
      );

      final p = await api.updateDraftPuzzlet('pz1', answer: 'cat', difficulty: 7);
      expect(p.answer, 'cat');
      expect(p.difficulty, 7);
    });

    test('listMyDrafts parses both lists', () async {
      adapter.onGet(
        '/poles/drafts/mine',
        (server) => server.reply(200, {
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
              'creator_id': 'u1',
              'inserted_at': null,
            }
          ],
          'puzzlets': [],
        }),
      );

      final drafts = await api.listMyDrafts();
      expect(drafts.poles, hasLength(1));
      expect(drafts.puzzlets, isEmpty);
    });
  });
}
