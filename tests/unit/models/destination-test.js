import { module, test } from 'qunit';
import { setupTest } from 'ember-qunit';

import { run } from '@ember/runloop';

module('Unit | Model | destination', function(hooks) {
  setupTest(hooks);

  test('it generates a suggested mask', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {answer: 'ABC123'}));

    assert.equal(model.get('suggestedMask'), 'ABC___');
  });

  test('it suggests a maximum of three of the rightmost blanks', function(assert) {
    const model = run(() => this.owner.lookup('service:store').createRecord('destination', {answer: 'A0C1234'}));

    assert.equal(model.get('suggestedMask'), 'A0C1___');
  });
});
