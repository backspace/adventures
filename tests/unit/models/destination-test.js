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

  test('a mask is valid when it matches the answer', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {
      answer: 'ABC123',
      mask: 'ABC___'
    }));

    assert.ok(model.get('maskIsValid'));
  });

  test('a mask is valid when it masks a subset of the answer’s numbers', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {
      answer: 'ABC123',
      mask: 'ABC1_3'
    }));

    assert.ok(model.get('maskIsValid'));
  });

  test('a mask is invalid if it has a different length', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {
      answer: 'ABC123',
      mask: 'AB___'
    }));

    assert.notOk(model.get('maskIsValid'));
  });

  test('a mask is invalid when a letter differs', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {
      answer: 'ABC123',
      mask: 'ABD___'
    }));

    assert.notOk(model.get('maskIsValid'));
  });

  test('a mask is invalid when it has no blanks', function(assert) {
    let model = run(() => this.owner.lookup('service:store').createRecord('destination', {
      answer: 'ABC123',
      mask: 'ABC123'
    }));

    assert.notOk(model.get('maskIsValid'));
  });
});