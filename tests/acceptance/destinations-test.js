import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import PageObject from '../page-object';

const { collection, text } = PageObject;

const page = PageObject.create({
  destinations: collection({
    itemScope: '.destination',

    item: {
      description: text('.description')
    }
  })
});

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
  visit('/destinations');

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Ina-Karekh');
  });
});
