import { run } from '@ember/runloop';
import { waitUntil } from '@ember/test-helpers';

import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';
import { all } from 'rsvp';

import withSetting from '../helpers/with-setting';

import page from '../pages/teams';

let teamOne, teamTwo;

module('Acceptance | teams', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function (assert) {
    const store = this.owner.lookup('service:store');
    const done = assert.async();

    run(() => {
      teamOne = store.createRecord('team');
      teamTwo = store.createRecord('team');

      teamOne.setProperties({
        name: 'Team 1',
        riskAversion: 3,
        phones: [{ number: '2045551212', displaySize: '5.5' }],
      });

      teamTwo.setProperties({
        name: 'Team 2',
        riskAversion: 1,
        phones: [
          { number: '2040000000', displaySize: '4' },
          { number: '5140000000', displaySize: '5' },
        ],
      });

      all([teamOne.save(), teamTwo.save()]).then(() => {
        done();
      });
    });
  });

  test('existing teams are listed', async function (assert) {
    await page.visit();

    assert.equal(page.teams.length, 2, 'expected two teams to be listed');

    assert.equal(page.teams[0].name, 'Team 1');
    assert.equal(page.teams[0].riskAversion, '3');
    assert.equal(page.teams[0].phones, '2045551212: 5.5');

    assert.equal(page.teams[1].name, 'Team 2');
    assert.equal(page.teams[1].riskAversion, '1');
    assert.equal(page.teams[1].phones, '2040000000: 4, 5140000000: 5');
  });

  test('teams can be added and updated with JSON input', async function (assert) {
    await page.visit();

    await page.enterJSON(`
      {
        "data": [
          {
            "type": "teams",
            "id": "${teamOne.id}",
            "attributes": {
              "name": "jorts",
              "users": "jorts@example.com, jants@example.com",
              "notes": "some notes",
              "phones": [
                {"number": "2041231234", "displaySize": "5.75"}
              ],
              "riskAversion": 2
            }
          },
          {
            "type": "teams",
            "id": "daa14876-7bb7-486c-8ed5-5287156a430b",
            "attributes": {
              "name": "jants",
              "riskAversion": 2
            }
          }
        ]
      }
    `);

    await page.save();

    assert.equal(page.teams.length, 3, 'expected three teams to be listed');

    assert.equal(page.teams[0].name, 'jants');
    assert.equal(
      page.teams[0].id,
      'daa14876-7bb7-486c-8ed5-5287156a430b',
      'expected newly-specified id to be used'
    );
    assert.equal(page.teams[0].riskAversion, '2');

    assert.equal(page.teams[1].name, 'jorts');
    assert.equal(
      page.teams[1].id,
      teamOne.id,
      'expected existing id to be preserved'
    );
    assert.equal(page.teams[1].users, 'jorts@example.com, jants@example.com');
    assert.equal(page.teams[1].phones, '2041231234: 5.75');
    assert.equal(page.teams[1].notes, 'some notes');
    assert.equal(page.teams[1].riskAversion, '2');

    assert.notOk(page.teams[1].identifier.isVisible);

    assert.equal(page.teams[2].name, 'Team 2');
  });

  test('teams can have identifiers for unmnemonic devices', async function (assert) {
    await withSetting(this.owner, 'unmnemonic-devices');
    await page.visit();

    await page.enterJSON(`
      {
        "data": [
          {
            "type": "teams",
            "id": 100,
            "attributes": {
              "name": "jorts",
              "users": "jorts@example.com, jants@example.com",
              "notes": "some notes",
              "phones": [
                {"number": "2041231234", "displaySize": "5.75"}
              ],
              "identifier": "i wont do what you tell me",
              "riskAversion": 2
            }
          }
        ]
      }
    `);

    await page.save();

    assert.equal(page.teams[0].name, 'jorts');
    assert.equal(page.teams[0].identifier.text, 'i wont do what you tell me');
  });
});
