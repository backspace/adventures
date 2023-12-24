import { setupTest } from 'ember-qunit';
import cmToPt from 'gathering/utils/cm-to-pt';
import { module, test } from 'qunit';

module('Unit | Service | unmnemonic-devices', function (hooks) {
  setupTest(hooks);

  test('it accepts all descriptions', function (assert) {
    let service = this.owner.lookup('service:unmnemonic-devices');

    assert.ok(service.descriptionIsValid());
  });

  test('preExcerpt returns the text before the excerpt', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');
    assert.strictEqual(service.preExcerpt('an|excerpt|exists'), 'an');
  });

  test('trimmedInnerExcerpt returns the text inside the excerpt without punctuation', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');
    assert.strictEqual(
      service.trimmedInnerExcerpt('an|excerpt,.?!: but|exists'),
      'excerpt but',
    );
  });

  test('postExcerpt returns the text before the excerpt', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');
    assert.strictEqual(service.postExcerpt('an|excerpt|exists'), 'exists');
  });

  test('it suggests masks', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');

    assert.strictEqual(
      service.suggestedMask('one two three'),
      'one ___ three',
      'expected a suggested mask with the middle word blanked',
    );
    assert.strictEqual(
      service.suggestedMask('one two three four'),
      'one ___ _____ four',
      'expected a suggested mask with the middle words blanked',
    );
    assert.strictEqual(
      service.suggestedMask('one'),
      '___',
      'expected a suggested mask entirely blanked with only one word',
    );
  });

  test('it extracts answers', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');

    assert.strictEqual(
      service.extractAnswer('one two three', 'one ___ three'),
      'two',
    );

    assert.throws(function () {
      service.extractAnswer('one two three', 'o _ t');
    });
  });
});

module(
  'Unit | Service | unmnemonic-devices | excerptIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks excerpt validity', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.ok(service.excerptIsValid('an|excerpt|exists'));

      assert.notOk(
        service.excerptIsValid('a partial | excerpt'),
        'excerpt should have two pipes',
      );

      assert.notOk(
        service.excerptIsValid('a broken | excerpt | yes | it is'),
        'excerpt should have two pipes',
      );

      assert.notOk(
        service.excerptIsValid('x'),
        'excerpt should have two pipes',
      );
      assert.notOk(service.excerptIsValid(null), 'excerpt should exist');
    });
  },
);

module(
  'Unit | Service | unmnemonic-devices | dimensionsIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks dimensions validity', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.ok(service.dimensionsIsValid('13.1,14.3'));

      assert.notOk(
        service.dimensionsIsValid('13.1 14.3'),
        'dimensions should have a separating comma',
      );

      assert.notOk(
        service.dimensionsIsValid('13.1,14.3,13.1'),
        'there should only be two numbers',
      );

      assert.notOk(
        service.dimensionsIsValid('13.x,14.y'),
        'both should be numbers',
      );

      assert.notOk(
        service.dimensionsIsValid('-13.1,14.3'),
        'both should be positive',
      );

      assert.notOk(
        service.dimensionsIsValid('13.1,0'),
        'both should be positive',
      );

      assert.notOk(service.dimensionsIsValid(null), 'should exist');
    });
  },
);

module(
  'Unit | Service | unmnemonic-devices | parsedDimensions',
  function (hooks) {
    setupTest(hooks);

    test('it parses dimensions', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.deepEqual(service.parsedDimensions('13.1,14.3'), [
        cmToPt(13.1),
        cmToPt(14.3),
      ]);
    });
  },
);

module(
  'Unit | Service | unmnemonic-devices | outlineIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks outline validity', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.ok(service.outlineIsValid('(3.2,2.3),1.5,-0.5'));

      assert.ok(
        service.outlineIsValid('(3.2,2.3),1.5,-0.5|(3.2,2.3),1.5,-0.5'),
      );

      assert.notOk(service.outlineIsValid(null), 'outline must be present');

      assert.notOk(
        service.outlineIsValid('(-3.2,0),1.5,2'),
        'first point cannot be negative',
      );

      assert.notOk(
        service.outlineIsValid('(0,-2.3),1.5,2'),
        'second point cannot be negative',
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5,0'),
        'displacements cannot be zero',
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5,3.x'),
        'displacements must be floats',
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5'),
        'there must be at least two displacement points',
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3)'),
        'there must be at least two displacement points',
      );
      assert.notOk(service.outlineIsValid('(0'), 'there must be a first point');
      assert.notOk(
        service.outlineIsValid('(0,1'),
        'there must be a first point',
      );
      assert.notOk(
        service.outlineIsValid('(0)'),
        'there must be a first point',
      );
      assert.notOk(service.outlineIsValid(''), 'there must be a first point');
    });
  },
);

module('Unit | Service | unmnemonic-devices | parsedOutline', function (hooks) {
  setupTest(hooks);

  hooks.before((assert) => {
    assert.outlineEqual = function (expectedOutline, actualOutline, message) {
      let results = [];

      let pairs = [
        { name: 'end', pair: [expectedOutline.end, actualOutline.end] },
        ...expectedOutline.points.map((point, index) => ({
          name: `points[${index}]`,
          pair: [point, actualOutline.points[index]],
        })),
      ];

      pairs.forEach((pair) => {
        let [expected, actual] = pair.pair;

        let xMatches = close(expected[0], actual[0]);
        let yMatches = close(expected[1], actual[1]);

        if (xMatches && yMatches) {
          results.push({
            result: true,
            message: `${message}: ${pair.name} matches`,
          });
        } else {
          if (!xMatches) {
            results.push({
              result: false,
              message: `${message}: ${pair.name} x ${expected[0]} ≠ ${actual[0]}`,
            });
          }

          if (!yMatches) {
            results.push({
              result: false,
              message: `${message}: ${pair.name} y ${expected[1]} ≠ ${actual[1]}`,
            });
          }
        }
      });

      if (results.every((result) => result.result)) {
        this.pushResult({
          result: true,
          message,
        });
      } else {
        results.forEach((result) => this.pushResult(result));
      }
    };
  });

  test('it parses outlines', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');

    let [p1, p2] = service.parsedOutline('(3.2,2.3),1.5,0.5|(3.2,2.3),1.5,0.5');

    assert.outlineEqual(
      p1,
      {
        end: [cmToPt(3.2 + 1.5), cmToPt(2.3)],
        points: [
          [cmToPt(3.2), cmToPt(2.3)],
          [cmToPt(3.2 + 1.5), cmToPt(2.3)],
          [cmToPt(3.2 + 1.5), cmToPt(2.3 + 0.5)],
          [cmToPt(3.2), cmToPt(2.3 + 0.5)],
          [cmToPt(3.2), cmToPt(2.3)],
        ],
      },
      'it closes the polygon',
    );

    assert.outlineEqual(p2, {
      end: [cmToPt(3.2 + 1.5), cmToPt(2.3)],
      points: [
        [cmToPt(3.2), cmToPt(2.3)],
        [cmToPt(3.2 + 1.5), cmToPt(2.3)],
        [cmToPt(3.2 + 1.5), cmToPt(2.3 + 0.5)],
        [cmToPt(3.2), cmToPt(2.3 + 0.5)],
        [cmToPt(3.2), cmToPt(2.3)],
      ],
    });
  });
});

function close(a, b) {
  return Math.abs(a - b) < 0.00001;
}
