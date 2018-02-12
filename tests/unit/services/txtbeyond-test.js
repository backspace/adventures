import { module, test } from 'qunit';
import { setupTest } from 'ember-qunit';

module('Unit | Service | txtbeyond', function(hooks) {
  setupTest(hooks);

  test('it suggests masks', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.equal(service.suggestedMask('one two three'), 'one ___ three', 'expected a suggested mask with the middle word blanked');
    assert.equal(service.suggestedMask('one'), '___', 'expected a suggested mask entirely blanked with only one word');
  });

  test('it checks mask validity', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.ok(service.maskIsValid('hello there', 'hello _____'), 'expected the mask to be valid when it matches the answer');
    assert.ok(service.maskIsValid('hello there', 'hello the__'), 'expected the mask to be valid when it masks a subset of the answer');

    assert.notOk(service.maskIsValid('hello there', 'hello there ___'), 'expected the mask to be invalid when it’s a different length');
    assert.notOk(service.maskIsValid('hello there', 'horlo _____'), 'expected the mask to be invalid when a letter differs');
    assert.notOk(service.maskIsValid('hello there', 'hello there'), 'expected the mask to be invalid when it has no blanks');
  });

  test('it checks description validity', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.ok(service.descriptionIsValid('hey this has a ~masked~ word'), 'expected a description with a masked word to be valid');
    assert.notOk(service.descriptionIsValid('this has no masked word'), 'expected a description with no masked word to be invalid');
    assert.notOk(service.descriptionIsValid('this ~has~ invalid ~masking'), 'expected a description with invalid masking to be invalid');
  });

  test('it removes masks from descriptions', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.equal(service.maskedDescription('this is ~masked~'), 'this is ______');
    assert.equal(service.maskedDescription('~is~ this ~masked~'), '__ this ______');
  });

  test('it extracts masks from descriptions', function(assert) {
    const service = this.owner.lookup('service:txtbeyond');

    assert.deepEqual(service.descriptionMasks('~is~ this ~masked~'), ['is', 'masked']);
  });
});
