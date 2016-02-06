import { moduleForModel, test } from 'ember-qunit';

moduleForModel('destination', 'Unit | Model | destination', {
  needs: ['model:meeting', 'model:region']
});

test('it generates a suggested mask', function(assert) {
  let model = this.subject({answer: 'ABC123'});

  assert.equal(model.get('suggestedMask'), 'ABC___');
});
