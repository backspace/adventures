import 'package:flutter_test/flutter_test.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';

void main() {
  ViewerPuzzlet p(String id,
          {String? region, int difficulty = 1, bool located = true}) =>
      ViewerPuzzlet(
        id: id,
        regionId: region,
        instructions: 'clue $id',
        answer: 'a',
        answerType: 'loose_text',
        difficulty: difficulty,
        latitude: located ? 1.0 : null,
        longitude: located ? 2.0 : null,
      );

  ViewerRegion r(String id, String name) => ViewerRegion(id: id, name: name);

  test('named regions first (alphabetical), no-region bucket last', () {
    final data = ViewerDataset(
      regions: [r('b', 'Beta'), r('a', 'Alpha')],
      puzzlets: [
        p('1', region: 'b', difficulty: 2),
        p('2', region: 'a', difficulty: 1),
        p('3', region: 'a', difficulty: 0),
        p('4', region: null),
        p('5', region: 'ghost'), // unknown region id → no-region bucket
      ],
    );

    final groups = data.groupedByRegion();
    expect(groups.map((g) => g.title), ['Alpha', 'Beta', 'No region']);
    // Within Alpha, ordered by difficulty (0 then 1).
    expect(groups[0].puzzlets.map((x) => x.id), ['3', '2']);
    // Null-region and unknown-region puzzlets both land in the trailing bucket.
    expect(groups.last.region, isNull);
    expect(groups.last.puzzlets.map((x) => x.id).toSet(), {'4', '5'});
  });

  test('located count reflects puzzlets with coordinates', () {
    final data = ViewerDataset(
      regions: [r('a', 'A')],
      puzzlets: [
        p('1', region: 'a', located: true),
        p('2', region: 'a', located: false),
      ],
    );
    final g = data.groupedByRegion().single;
    expect(g.puzzlets.length, 2);
    expect(g.located, 1);
  });

  test('regionById resolves known ids and nulls otherwise', () {
    final data = ViewerDataset(regions: [r('a', 'Alpha')]);
    expect(data.regionById('a')?.name, 'Alpha');
    expect(data.regionById('nope'), isNull);
    expect(data.regionById(null), isNull);
  });
}
