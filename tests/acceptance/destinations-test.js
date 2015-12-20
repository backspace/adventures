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

  new: clickable('.new'),

  descriptionField: {
    scope: 'textarea.description',
    value: value(),
    fill: fillable()
  },

  accessibilityField: {
    scope: 'textarea.accessibility',
    value: value(),
    fill: fillable()
  },

  save: clickable('.save'),
  cancel: clickable('.cancel')
});

moduleForAcceptance('Acceptance | destinations', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixtureOne = store.createRecord('destination');
        const fixtureTwo = store.createRecord('destination');

        fixtureOne.setProperties({
          description: 'Ina-Karekh',
          accessibility: 'You might need help'
        });

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

test('a destination can be created', (assert) => {
  visit('/destinations');

  page.new();
  page.descriptionField().fill('Bromarte');
  page.save();

  andThen(() => {
    assert.equal(page.destinations(3).description(), 'Bromarte');
  });
});

test('a destination can be edited and edits can be cancelled', (assert) => {
  visit('/destinations');

  page.destinations(1).edit();

  andThen(() => {
    assert.equal(page.descriptionField().value(), 'Ina-Karekh');
    assert.equal(page.accessibilityField().value(), 'You might need help');
  });

  page.descriptionField().fill('Kisua');
  page.accessibilityField().fill('You must cross the Empty Thousand!');
  page.save();

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Kisua');
  });

  page.destinations(1).edit();

  andThen(() => {
    assert.equal(page.accessibilityField().value(), 'You must cross the Empty Thousand!');
  });

  page.descriptionField().fill('Banbarra');
  page.cancel();

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Kisua');
  });
});
