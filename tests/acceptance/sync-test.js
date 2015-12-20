import Ember from 'ember';

import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import PageObject from '../page-object';

const { clickable, fillable, text } = PageObject;

const page = PageObject.create({
  visit: clickable('a.sync'),

  enterDestination: fillable('input.destination'),
  sync: clickable('button.sync'),

  push: {
    scope: 'tr.push',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures')
  },

  pull: {
    scope: 'tr.pull',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures')
  }
});

moduleForAcceptance('Acceptance | sync', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const fixture = store.createRecord('destination');

        fixture.set('description', 'Ina-Karekh');

        fixture.save().then(() => {
          resolve();
        });
      });
    });
  }
});

test('can sync with another database', function(assert) {
  const done = assert.async();

  visit('/');
  page.visit();

  page.enterDestination('sync-db').sync();

  andThen(() => {
    const syncController = this.application.__container__.lookup('controller:sync');

    syncController.get('syncPromise').then(() => {
      assert.equal(page.push().read(), '1');
      assert.equal(page.push().written(), '1');
      assert.equal(page.push().writeFailures(), '0');

      // FIXME the sync db is accumulating documents
      //assert.equal(page.pull().read(), '0');
      //assert.equal(page.pull().written(), '0');
      assert.equal(page.pull().writeFailures(), '0');

      done();
    });
  });
});
