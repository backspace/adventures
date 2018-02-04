import { module, test } from 'qunit';
import { setupTest } from 'ember-qunit';

module('Unit | Service | txtbeyond | suggestedMask', function(hooks) {
  setupTest(hooks);

  test('it suggests masks', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.equal(service.suggestedMask('one two three'), 'one ___ three', 'expected a suggested mask with the middle word blanked');
  });
});
