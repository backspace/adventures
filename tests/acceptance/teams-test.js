import Ember from 'ember';
import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import page from '../pages/teams';

moduleForAcceptance('Acceptance | teams', {
  beforeEach(assert) {
    const store = this.application.__container__.lookup('service:store');
    const done = assert.async();

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
        done();
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

test('teams can be overwritten with JSON input', (assert) => {
  page.visit();

  page.enterJSON(`
    {
      "data": [
        {
          "type": "teams",
          "id": 100,
          "attributes": {
            "name": "jorts",
            "users": "jorts@example.com, jants@example.com",
            "riskAversion": 2
          }
        },
        {
          "type": "teams",
          "id": 200,
          "attributes": {
            "name": "jants",
            "riskAversion": 2
          }
        }
      ]
    }
  `);

  page.save();

  andThen(function() {
    assert.equal(page.teams().count(), 2, 'expected two teams to be listed');

    assert.equal(page.teams(1).name(), 'jorts');
    assert.equal(page.teams(1).users(), 'jorts@example.com, jants@example.com');
    assert.equal(page.teams(1).riskAversion(), '2');

    assert.equal(page.teams(2).name(), 'jants');
    assert.equal(page.teams(2).riskAversion(), '2');
  });
});
