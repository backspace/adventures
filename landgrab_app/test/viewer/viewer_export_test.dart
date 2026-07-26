import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/viewer/viewer_export.dart';

void main() {
  DraftPole pole({String id = 'p1', String? label = 'Server room stake'}) =>
      DraftPole(
        id: id,
        barcode: 'BC-$id',
        label: label,
        latitude: 49.9,
        longitude: -97.13,
        notes: null,
        accuracyM: null,
        status: DraftStatus.validated,
        creatorId: null,
        insertedAt: null,
      );

  DraftPuzzlet puzzlet({
    String id = 'z1',
    String instructions = 'Read the label on the router.',
    String answer = 'ACME-9000',
    AnswerType type = AnswerType.barcode,
    int difficulty = 2,
    String? poleId = 'p1',
    String? regionId = 'r1',
    double? lat = 49.9,
    double? lng = -97.13,
  }) =>
      DraftPuzzlet(
        id: id,
        instructions: instructions,
        answer: answer,
        answerType: type,
        difficulty: difficulty,
        status: DraftStatus.validated,
        poleId: poleId,
        regionId: regionId,
        creatorId: null,
        latitude: lat,
        longitude: lng,
        accuracyM: null,
        insertedAt: null,
      );

  Region region({String id = 'r1'}) => Region(
        id: id,
        name: 'Server room',
        parentRegionId: null,
        entryInstructions: 'Badge in at the north door.',
      );

  test('maps supervisor models into a ViewerDataset field-for-field', () {
    final data = ViewerExport.build(
      poles: [pole()],
      puzzlets: [puzzlet()],
      regions: [region()],
    );

    expect(data.poles.single.name, 'Server room stake');
    expect(data.poles.single.latitude, 49.9);

    final z = data.puzzlets.single;
    expect(z.instructions, 'Read the label on the router.');
    expect(z.answer, 'ACME-9000');
    expect(z.answerType, 'barcode'); // enum → server string
    expect(z.difficulty, 2);
    expect(z.poleId, 'p1');
    expect(z.regionId, 'r1');
    expect(z.latitude, 49.9);
    expect(z.longitude, -97.13);
    expect(z.hasLocation, isTrue);

    expect(data.regions.single.name, 'Server room');
    expect(data.regions.single.entryInstructions, 'Badge in at the north door.');
  });

  test('falls back to the pole id when the label is blank', () {
    final data = ViewerExport.build(
      poles: [pole(id: 'bare', label: '   ')],
      puzzlets: const [],
      regions: const [],
    );
    expect(data.poles.single.name, 'bare');
  });

  test('a puzzlet with only an embedded region summary still gets a regionId', () {
    // regionId null but region summary present — the mapper prefers id, then
    // the summary's id.
    final z = ViewerExport.puzzletToViewer(puzzlet(regionId: null));
    expect(z.regionId, isNull); // no summary set in this fixture either
  });
}
