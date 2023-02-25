import { run } from '@ember/runloop';
import { visit, waitUntil } from '@ember/test-helpers';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';
import { all } from 'rsvp';

import withSetting, { withoutSetting } from '../helpers/with-setting';

import page from 'adventure-gathering/tests/pages/waypoints';
import homePage from 'adventure-gathering/tests/pages/home';

module('Acceptance | waypoints', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function (assert) {
    await withSetting(this.owner, 'unmnemonic-devices');

    const store = this.owner.lookup('service:store');

    const regionOne = store.createRecord('region');
    const regionTwo = store.createRecord('region');

    regionOne.set('name', 'Harvey Smith');
    regionTwo.set('name', 'Henderson');

    await regionOne.save();
    await regionTwo.save();

    const waypointOne = store.createRecord('waypoint');

    waypointOne.setProperties({
      name: 'The Shadowed Sun',
      author: 'N. K. Jemisin',
      call: 'FICTION SCI JEMISIN',
      region: regionOne,
    });

    await waypointOne.save();
    await regionOne.save();

    const waypointTwo = store.createRecord('waypoint');

    waypointTwo.setProperties({
      name: 'The Killing Moon',
      author: 'N. K. Jemisin',
      call: 'FICTION SCI JEMISIN',
      region: regionTwo,
    });

    await waypointTwo.save();
    await regionTwo.save();
  });

  test('waypoints show for unmnemonic devices', async function (assert) {
    await homePage.visit();

    assert.ok(homePage.waypoints.isPresent);
  });

  test('waypoints do not show otherwise', async function (assert) {
    await withoutSetting(this.owner, 'unmnemonic-devices');
    await homePage.visit();

    assert.notOk(homePage.waypoints.isPresent);
  });

  test('existing waypoints are listed', async function (assert) {
    await homePage.visit();
    await homePage.waypoints.click();

    page.waypoints[0].as((one) => {
      assert.equal(one.name, 'The Shadowed Sun');
      assert.equal(one.author, 'N. K. Jemisin');
      assert.equal(one.region, 'Harvey Smith');
    });

    page.waypoints[1].as((two) => {
      assert.equal(two.name, 'The Killing Moon');
      assert.equal(two.author, 'N. K. Jemisin');
      assert.equal(two.region, 'Henderson');
    });
  });
});
