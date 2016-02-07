import { moduleFor, test } from 'ember-qunit';

moduleFor('service:puzzles', 'Unit | Service | puzzles | chooseBlankIndex');

test('it chooses a blank index', function(assert) {
  const service = this.subject();

  assert.equal(
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_3',
      goalDigit: 9
    }),
  1, 'expected the only blank index');

  assert.equal(
    service.chooseBlankIndex({
      answer: '321',
      mask: '___',
      goalDigit: 9
    }),
  2, 'expected the farthest-away blank index');

  assert.equal(
    service.chooseBlankIndex({
      answer: '222',
      mask: '___',
      goalDigit: 9
    }),
  0, 'expected the first farthest-away blank index');
});

test('throws if the answer and mask have a mismatch', function(assert) {
  const service = this.subject();

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_5',
      goalDigit: 9
    });
  }, 'expected an error when a non-masked digit did not match');

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '1_34',
      goalDigit: 9
    });
  }, 'expected an error when the mask was longer than the answer');

  assert.throws(() => {
    service.chooseBlankIndex({
      answer: '123',
      mask: '123',
      goalDigit: 9
    });
  }, 'expected an error when the mask had no blanks');
});
