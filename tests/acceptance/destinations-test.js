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
      awesomeness: text('.awesomeness'),
      risk: text('.risk'),

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

  awesomenessField: {
    scope: 'input.awesomeness',
    value: value(),
    fill: fillable()
  },

  riskField: {
    scope: 'input.risk',
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
          accessibility: 'You might need help',
          awesomeness: 9,
          risk: 6
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

test('a destination can be created and will appear at the top of the list', (assert) => {
  visit('/destinations');

  page.new();
  page.descriptionField().fill('Bromarte');
  page.save();

  andThen(() => {
    assert.equal(page.destinations(1).description(), 'Bromarte');
  });
});

test('a destination can be edited and edits can be cancelled', (assert) => {
  visit('/destinations');

  page.destinations(1).edit();

  andThen(() => {
    assert.equal(page.descriptionField().value(), 'Ina-Karekh');
    assert.equal(page.accessibilityField().value(), 'You might need help');
    assert.equal(page.awesomenessField().value(), '9');
    assert.equal(page.riskField().value(), '6');
  });

  page.descriptionField().fill('Kisua');
  page.accessibilityField().fill('You must cross the Empty Thousand!');
  page.awesomenessField().fill(10);
  page.riskField().fill(5);
  page.save();

  andThen(() => {
    const destination = page.destinations(1);
    assert.equal(destination.description(), 'Kisua');
    assert.equal(destination.awesomeness(), '10');
    assert.equal(destination.risk(), '5');
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
