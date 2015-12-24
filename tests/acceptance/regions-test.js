import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import PageObject from '../page-object';

const { collection, text, visitable } = PageObject;

const page = PageObject.create({
  visit: visitable('/regions'),

  regions: collection({
    itemScope: '.region',

    item: {
      name: text('.name')
    }
  })
});

moduleForAcceptance('Acceptance | regions', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixtureOne = store.createRecord('region');
        const fixtureTwo = store.createRecord('region');

        fixtureOne.set('name', 'Gujaareh');
        fixtureTwo.set('name', 'Kisua');

        Ember.RSVP.all([fixtureOne.save, fixtureTwo.save]).then(() => {
          resolve();
        });
      });
    });
  }
});

test('existing regions are listed', function(assert) {
  page.visit();

  andThen(function() {
    assert.equal(page.regions().count(), 2, 'expected two regions to be listed');
    assert.equal(page.regions(1).name(), 'Gujaareh');
    assert.equal(page.regions(2).name(), 'Kisua');
  });
});
