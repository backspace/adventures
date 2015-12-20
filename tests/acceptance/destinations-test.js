import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import PageObject from '../page-object';

const { clickable, collection, fillable, text, value } = PageObject;

const page = PageObject.create({
  destinations: collection({
    itemScope: '.destination',

    item: {
      description: text('.description'),

      edit: clickable('.edit')
    }
  }),

  descriptionField: {
    scope: 'textarea.description',
    value: value(),
    fill: fillable()
  },

  save: clickable('.save')
});

moduleForAcceptance('Acceptance | destinations', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixtureOne = store.createRecord('destination');
        const fixtureTwo = store.createRecord('destination');

        fixtureOne.set('description', 'Ina-Karekh');
        fixtureTwo.set('description', 'Hona-Karekh');

        Ember.RSVP.all([fixtureOne.save, fixtureTwo.save]).then(() => {
          resolve();
        });
      });
    });
  }
});

test('existing destinations are listed', (assert) => {
  visit('/destinations');

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Ina-Karekh');
    assert.equal(page.destinations(2).description(), 'Hona-Karekh');
  });
});

test('a destination can be edited', (assert) => {
  visit('/destinations');

  page.destinations(1).edit();

  andThen(() => {
    assert.equal(page.descriptionField().value(), 'Ina-Karekh');
  });

  page.descriptionField().fill('Kisua');
  page.save();

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Kisua');
  });
});
