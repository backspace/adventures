import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

moduleForAcceptance('Acceptance | destinations', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixture = store.createRecord('destination');
        fixture.set('description', 'Ina-Karekh');
        return resolve(fixture.save);
      });
    });
  }
});

test('existing destinations are listed', (assert) => {
  visit('/');

  andThen(() => {
    assert.equal(find('.destination .description').text(), 'Ina-Karekh');
  });
});
