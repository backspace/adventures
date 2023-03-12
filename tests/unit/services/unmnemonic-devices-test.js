import { setupTest } from 'ember-qunit';
import { module, test } from 'qunit';

module('Unit | Service | unmnemonic-devices', function (hooks) {
  setupTest(hooks);

  test('it accepts all descriptions and masks', function (assert) {
    let service = this.owner.lookup('service:unmnemonic-devices');

    assert.ok(service.descriptionIsValid());
    assert.ok(service.maskIsValid());
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
  'Unit | Service | unmnemonic-devices | outlineIsValid',
  function (hooks) {
    setupTest(hooks);

    test('it checks outline validity', function (assert) {
      const service = this.owner.lookup('service:unmnemonic-devices');

      assert.ok(service.outlineIsValid('(3.2,2.3),1.5'));
      assert.ok(service.outlineIsValid('(3.2,2.3),1.5,-0.5'));

      assert.notOk(service.outlineIsValid(null), 'outline must be present');

      assert.notOk(
        service.outlineIsValid('(-3.2,0),1.5'),
        'first point cannot be negative'
      );

      assert.notOk(
        service.outlineIsValid('(0,-2.3),1.5'),
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
    });
  }
);
