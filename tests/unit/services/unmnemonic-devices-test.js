import cmToPt from 'adventure-gathering/utils/cm-to-pt';
import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';

module('Unit | Service | unmnemonic-devices', function (hooks) {
  setupTest(hooks);

  test('it accepts all descriptions and masks', function (assert) {
    let service = this.owner.lookup('service:unmnemonic-devices');

    assert.ok(service.descriptionIsValid());
    assert.ok(service.maskIsValid());
  });

  test('preExcerpt returns the text before the excerpt', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');
    assert.equal(service.preExcerpt('an|excerpt|exists'), 'an');
  });

  test('postExcerpt returns the text before the excerpt', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');
    assert.equal(service.postExcerpt('an|excerpt|exists'), 'exists');
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
        'excerpt should have two pipes'
      );

      assert.notOk(
        service.excerptIsValid('a broken | excerpt | yes | it is'),
        'excerpt should have two pipes'
      );

      assert.notOk(service.excerptIsValid(null), 'excerpt should exist');
    });
  }
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
        'dimensions should have a separating comma'
      );

      assert.notOk(
        service.dimensionsIsValid('13.1,14.3,13.1'),
        'there should only be two numbers'
      );

      assert.notOk(
        service.dimensionsIsValid('13.x,14.y'),
        'both should be numbers'
      );

      assert.notOk(
        service.dimensionsIsValid('-13.1,14.3'),
        'both should be positive'
      );

      assert.notOk(
        service.dimensionsIsValid('13.1,0'),
        'both should be positive'
      );
    });
  }
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
  }
);

module(
  'Unit | Service | unmnemonic-devices | outlineIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks outline validity', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.ok(service.outlineIsValid('(3.2,2.3),1.5,-0.5'));

      assert.notOk(service.outlineIsValid(null), 'outline must be present');

      assert.notOk(
        service.outlineIsValid('(-3.2,0),1.5,2'),
        'first point cannot be negative'
      );

      assert.notOk(
        service.outlineIsValid('(0,-2.3),1.5,2'),
        'second point cannot be negative'
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5,0'),
        'displacements cannot be zero'
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5,3.x'),
        'displacements must be floats'
      );

      assert.notOk(
        service.outlineIsValid('(0,2.3),1.5'),
        'there must be at least two displacement points'
      );
    });
  }
);

module('Unit | Service | unmnemonic-devices | parsedOutline', function (hooks) {
  setupTest(hooks);

  test('it parses outlines', function (assert) {
    const service = this.owner.lookup('service:unmnemonic-devices');

    assert.deepEqual(
      service.parsedOutline('(3.2,2.3),1.5,-0.5'),
      [
        [cmToPt(3.2), cmToPt(2.3)],
        [
          [cmToPt(3.2 + 1.5), cmToPt(2.3)],
          [cmToPt(3.2 + 1.5), cmToPt(2.3 + -0.5)],
          [cmToPt(3.2), cmToPt(2.3 + -0.5)],
          [cmToPt(3.2), cmToPt(2.3)],
        ],
      ],
      'it closes the polygon'
    );
  });
});
