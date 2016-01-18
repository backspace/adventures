import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/teams';

moduleForAcceptance('Acceptance | teams', {
  beforeEach() {
    const store = this.application.__container__.lookup('service:store');

    return new Ember.RSVP.Promise((resolve) => {
      Ember.run(() => {
        const teamOne = store.createRecord('team');
        const teamTwo = store.createRecord('team');

        teamOne.setProperties({
          name: 'Team 1',
          riskAversion: 3
        });

        teamTwo.setProperties({
          name: 'Team 2',
          riskAversion: 1
        });

        Ember.RSVP.all([teamOne.save(), teamTwo.save()]).then(() => {
          resolve();
        });
      });
    });
  }
});

test('existing teams are listed', function(assert) {
  page.visit();

  andThen(function() {
    assert.equal(page.teams().count(), 2, 'expected two teams to be listed');

    assert.equal(page.teams(1).name(), 'Team 1');
    assert.equal(page.teams(1).riskAversion(), '3');

    assert.equal(page.teams(2).name(), 'Team 2');
    assert.equal(page.teams(2).riskAversion(), '1');
  });
});
