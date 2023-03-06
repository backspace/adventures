import { run } from '@ember/runloop';
import { visit, waitUntil } from '@ember/test-helpers';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import homePage from 'adventure-gathering/tests/pages/home';
import page from 'adventure-gathering/tests/pages/waypoints';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';
import { all } from 'rsvp';

import withSetting, { withoutSetting } from '../helpers/with-setting';

module('Acceptance | waypoints', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function (assert) {
    await withSetting(this.owner, 'unmnemonic-devices');

    const store = this.owner.lookup('service:store');

    const regionOne = store.createRecord('region');
    const regionTwo = store.createRecord('region');

    regionOne.set('name', 'Henderson');
    regionTwo.set('name', 'Harvey Smith');

    await regionOne.save();
    await regionTwo.save();

    const waypointOne = store.createRecord('waypoint');

    waypointOne.setProperties({
      name: 'The Killing Moon',
      author: 'N. K. Jemisin',
      call: 'FICTION SCI JEMISIN',
      region: regionOne,
    });

    await waypointOne.save();
    await regionOne.save();

    const waypointTwo = store.createRecord('waypoint');

    waypointTwo.setProperties({
      name: 'The Shadowed Sun',
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

  test('a waypoint can be created and will appear at the top of the list', async function (assert) {
    await homePage.visit();
    await homePage.waypoints.click();

    await page.new();
    await page.nameField.fill('A Half-Built Garden');
    await page.authorField.fill('Ruthanna Emrys');
    await page.callField.fill('FICTION SCI EMRYS');

    await page.save();
    await waitUntil(() => page.waypoints.length);

    assert.equal(page.waypoints[0].name, 'A Half-Built Garden');
    assert.equal(page.waypoints[0].author, 'Ruthanna Emrys');
  });

  test('a waypoint can be edited and edits can be cancelled', async function (assert) {
    await homePage.visit();
    await homePage.waypoints.click();
    await page.waypoints[0].edit();

    assert.equal(page.nameField.value, 'The Shadowed Sun');
    assert.equal(page.authorField.value, 'N. K. Jemisin');
    assert.equal(page.callField.value, 'FICTION SCI JEMISIN');

    await page.nameField.fill('The Fifth Season');
    await page.authorField.fill('NK');
    await page.callField.fill('978-0-356-50819-1');
    await page.save();
    await waitUntil(() => page.waypoints.length);

    page.waypoints[0].as((edited) => {
      assert.equal(edited.name, 'The Fifth Season');
      assert.equal(edited.author, 'NK');
    });

    await page.waypoints[0].edit();

    assert.equal(page.callField.value, '978-0-356-50819-1');

    await page.nameField.fill('The Obelisk Gate');
    await page.cancel();

    assert.equal(page.waypoints[0].name, 'The Fifth Season');
  });

  test('a new waypoint defaults to the same region as the previously-created one', async function (assert) {
    await homePage.visit();
    await homePage.waypoints.new();

    await page.nameField.fill('Borderlands');

    await page.regionField.fillByText('Henderson');

    await page.save();

    await page.new();

    assert.equal(page.regionField.text, 'Henderson');
  });
});
