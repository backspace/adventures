import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';

import withSetting from '../helpers/with-setting';

import page from '../pages/teams';

let teamOne, teamTwo;

module('Acceptance | teams', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function () {
    const store = this.owner.lookup('service:store');

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

    await teamOne.save();
    await teamTwo.save();
  });

  test('existing teams are listed', async function (assert) {
    await page.visit();

    assert.strictEqual(page.teams.length, 2, 'expected two teams to be listed');

    assert.strictEqual(page.teams[0].name.text, 'Team 1');
    assert.strictEqual(page.teams[0].riskAversion.text, '3');
    assert.strictEqual(page.teams[0].phones.text, '2045551212: 5.5');

    assert.strictEqual(page.teams[1].name.text, 'Team 2');
    assert.strictEqual(page.teams[1].riskAversion.text, '1');
    assert.strictEqual(
      page.teams[1].phones.text,
      '2040000000: 4, 5140000000: 5'
    );
  });

  test('teams can be added and updated with JSON input', async function (assert) {
    await page.visit();

    assert.ok(page.save.isDisabled);

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

    await page.update.click();

    assert.strictEqual(
      page.teams.length,
      3,
      'expected three teams to be listed'
    );
    assert.notOk(page.save.isDisabled);

    assert.ok(page.teams[0].isNew);
    assert.notOk(page.teams[0].hasChanges);

    assert.strictEqual(page.teams[0].name.text, 'jants');
    assert.strictEqual(
      page.teams[0].id,
      'daa14876-7bb7-486c-8ed5-5287156a430b',
      'expected newly-specified id to be used'
    );
    assert.strictEqual(page.teams[0].riskAversion.text, '2');

    assert.ok(page.teams[1].hasChanges);

    assert.ok(page.teams[1].name.isChanged);
    assert.strictEqual(page.teams[1].name.text, 'jorts');
    assert.strictEqual(page.teams[1].originalName, 'Team 1');

    assert.strictEqual(
      page.teams[1].id,
      teamOne.id,
      'expected existing id to be preserved'
    );

    assert.ok(page.teams[1].users.isChanged);
    assert.strictEqual(
      page.teams[1].users.text,
      'jorts@example.com, jants@example.com'
    );

    assert.ok(page.teams[1].phones.isChanged);
    assert.strictEqual(page.teams[1].phones.text, '2041231234: 5.75');

    assert.ok(page.teams[1].notes.isChanged);
    assert.strictEqual(page.teams[1].notes.text, 'some notes');

    assert.ok(page.teams[1].riskAversion.isChanged);
    assert.strictEqual(page.teams[1].riskAversion.text, '2');

    assert.notOk(page.teams[1].identifier.isVisible);

    assert.strictEqual(page.teams[2].name.text, 'Team 2');

    await page.save.click();

    assert.notOk(page.teams[0].isNew);
    assert.notOk(page.teams[1].hasChanges);

    assert.ok(page.save.isDisabled);
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

    await page.update.click();
    await page.save.click();

    assert.strictEqual(page.teams[0].name.text, 'jorts');
    assert.strictEqual(
      page.teams[0].identifier.text,
      'i wont do what you tell me'
    );
  });
});
