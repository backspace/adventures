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
