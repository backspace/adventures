import { waitUntil } from '@ember/test-helpers';
import resetStorages from 'ember-local-storage/test-support/reset-storage';
import { setupApplicationTest } from 'ember-qunit';
import homePage from 'gathering/tests/pages/home';
import nav from 'gathering/tests/pages/nav';
import page from 'gathering/tests/pages/waypoints';
import { module, test } from 'qunit';

import withSetting, { withoutSetting } from '../helpers/with-setting';

module('Acceptance | waypoints', function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(async function () {
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
      status: 'unavailable',
    });

    await waypointOne.save();
    await regionOne.save();

    const waypointTwo = store.createRecord('waypoint');

    waypointTwo.setProperties({
      name: 'The Shadowed Sun',
      author: 'N. K. Jemisin',
      call: 'FICTION SCI JEMISIN',
      credit: 'greatnesses',
      excerpt: 'on the|relations between pleasure and death,|which',
      page: '24',
      dimensions: '12,18.1',
      outline: '(7.3,10.6),3.6,.35,-3.1,.35,-1.5,-.35,1',
      region: regionTwo,
      status: 'available',
    });

    await waypointTwo.save();
    await regionTwo.save();
  });

  hooks.afterEach(function () {
    window.localStorage.clear();
    resetStorages();
  });

  test('waypoints show for unmnemonic devices', async function (assert) {
    await homePage.visit();

    assert.ok(nav.waypoints.isPresent);
  });

  test('waypoints do not show otherwise', async function (assert) {
    await withoutSetting(this.owner, 'unmnemonic-devices');
    await homePage.visit();

    assert.notOk(nav.waypoints.isPresent);
  });

  test('existing waypoints are listed', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();
    await page.headerRegion.click();

    let one = page.waypoints[0];
    assert.strictEqual(one.name, 'The Shadowed Sun');
    assert.strictEqual(one.author, 'N. K. Jemisin');
    assert.strictEqual(one.region.text, 'Harvey Smith');
    assert.notOk(one.isIncomplete);

    let two = page.waypoints[1];
    assert.strictEqual(two.name, 'The Killing Moon');
    assert.strictEqual(two.author, 'N. K. Jemisin');
    assert.strictEqual(two.region.text, 'Henderson');
    assert.ok(two.isIncomplete);
  });

  test('persisted sort is restored', async function (assert) {
    window.localStorage.setItem(
      'storage:waypoints',
      JSON.stringify({ sorting: 'region' }),
    );

    await homePage.visit();
    await nav.waypoints.click();
    assert.ok(page.headerRegion.isActive);
  });

  test('validation errors show on the form', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();
    await page.headerRegion.click();

    await page.waypoints[1].edit();

    assert.ok(page.outlineField.isInvalid);
    assert.strictEqual(page.outlineField.errors, 'required');

    await page.outlineField.fill('not a valid outline');
    assert.strictEqual(page.outlineField.errors, 'invalid');

    assert.notOk(page.regionField.isInvalid);

    await page.cancel();

    await page.waypoints[0].edit();

    assert.notOk(page.outlineField.isInvalid);
    assert.notOk(page.regionField.isInvalid);

    await page.cancel();
    await page.new();

    assert.ok(page.regionField.isInvalid);
    assert.strictEqual(page.regionField.errors, 'required');

    assert.ok(page.nameField.isInvalid);
    assert.strictEqual(page.nameField.errors, 'required');

    assert.notOk(page.authorField.isInvalid);

    assert.ok(page.callField.isInvalid);
    assert.strictEqual(page.callField.errors, 'required');

    assert.notOk(page.creditField.isInvalid);

    assert.ok(page.excerptField.isInvalid);
    assert.strictEqual(page.excerptField.errors, 'required');

    assert.ok(page.pageField.isInvalid);
    assert.strictEqual(page.pageField.errors, 'required');

    assert.ok(page.dimensionsField.isInvalid);
    assert.strictEqual(page.dimensionsField.errors, 'required');
  });

  test('waypoint status doesn’t show when the feature flag is off', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();

    assert.ok(
      page.waypoints[0].status.isHidden,
      'expected the status to be hidden',
    );
  });

  test('waypoint status is displayed and can be toggled from the list when the feature flag is on', async function (assert) {
    await withSetting(this.owner, 'destination-status');
    await homePage.visit();
    await nav.waypoints.click();

    assert.notOk(page.headerRegion.isActive);

    // Sort by region, otherwise waypoints will jump around
    await page.headerRegion.click();

    assert.ok(page.headerRegion.isActive);
    assert.strictEqual(page.waypoints[0].status.value, '✓');
    assert.strictEqual(page.waypoints[1].status.value, '✘');

    await page.waypoints[0].status.click();
    assert.strictEqual(page.waypoints[0].status.value, '✘');

    await page.waypoints[0].status.click();
    // TODO why does this help?
    await waitUntil(() => page.waypoints[0].status.value === '?');
    assert.strictEqual(page.waypoints[0].status.value, '?');
  });

  test('a waypoint can be created and will appear at the top of the list', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();

    await page.new();
    await page.nameField.fill('A Half-Built Garden');
    await page.authorField.fill('Ruthanna Emrys');
    await page.callField.fill('FICTION SCI EMRYS');

    await page.save();
    await waitUntil(() => page.waypoints.length);

    assert.strictEqual(page.waypoints[0].name, 'A Half-Built Garden');
    assert.strictEqual(page.waypoints[0].author, 'Ruthanna Emrys');
  });

  test('a region can be entered and waypoints will be scoped to it', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();
    await page.headerRegion.click();

    await page.waypoints[0].region.click();
    assert.strictEqual(page.region.title, 'Harvey Smith');
    assert.strictEqual(page.waypoints.length, 1);

    await nav.waypoints.click();
    assert.ok(page.region.isHidden);
    assert.strictEqual(page.waypoints.length, 2);

    await page.waypoints[0].region.click();
    await page.region.leave();
    assert.ok(page.region.isHidden);

    await page.waypoints[0].region.click();
    await page.new();
    assert.strictEqual(page.regionField.text, 'Harvey Smith');

    await page.save();
    await waitUntil(() => page.waypoints.length);

    assert.strictEqual(page.waypoints.length, 2);
  });

  test('the status fieldset doesn’t show when the feature isn’t on', async function (assert) {
    await homePage.visit();
    await nav.waypoints.click();

    await page.waypoints[0].edit();

    assert.ok(
      page.statusFieldset.isHidden,
      'expected the status fieldset to be hidden',
    );
  });

  test('a waypoint can be edited and edits can be cancelled', async function (assert) {
    await withSetting(this.owner, 'destination-status');
    await homePage.visit();
    await nav.waypoints.click();
    await page.headerRegion.click();
    await page.waypoints[0].edit();

    assert.strictEqual(page.nameField.value, 'The Shadowed Sun');
    assert.strictEqual(page.authorField.value, 'N. K. Jemisin');
    assert.strictEqual(page.callField.value, 'FICTION SCI JEMISIN');
    assert.strictEqual(page.creditField.value, 'greatnesses');

    assert.strictEqual(
      page.excerptField.value,
      'on the|relations between pleasure and death,|which',
    );
    assert.strictEqual(page.pageField.value, '24');
    assert.strictEqual(page.dimensionsField.value, '12,18.1');
    assert.strictEqual(
      page.outlineField.value,
      '(7.3,10.6),3.6,.35,-3.1,.35,-1.5,-.35,1',
    );

    await page.nameField.fill('The Fifth Season');
    await page.authorField.fill('NK');
    await page.callField.fill('978-0-356-50819-1');
    await page.creditField.fill('excellences');

    await page.excerptField.fill('activity|as it is absent of air.|Buildings');
    await page.pageField.fill('276');
    await page.dimensionsField.fill('12.1,16.4');
    await page.outlineField.fill('(2.2,1.5),1.8,.25');
    await page.statusFieldset.availableOption.click();

    await page.save();
    await waitUntil(() => page.waypoints.length);

    let edited = page.waypoints[0];
    assert.strictEqual(edited.name, 'The Fifth Season');
    assert.strictEqual(edited.author, 'NK');
    assert.strictEqual(edited.status.value, '✓');

    await page.waypoints[0].edit();

    assert.strictEqual(page.callField.value, '978-0-356-50819-1');
    assert.strictEqual(page.creditField.value, 'excellences');

    assert.strictEqual(
      page.excerptField.value,
      'activity|as it is absent of air.|Buildings',
    );
    assert.strictEqual(page.pageField.value, '276');
    assert.strictEqual(page.dimensionsField.value, '12.1,16.4');
    assert.strictEqual(page.outlineField.value, '(2.2,1.5),1.8,.25');

    await page.nameField.fill('The Obelisk Gate');
    await page.cancel();

    assert.strictEqual(page.waypoints[0].name, 'The Fifth Season');
  });

  test('a new waypoint defaults to the same region as the previously-created one', async function (assert) {
    await homePage.visit();
    await nav.waypoints.new();

    await page.nameField.fill('Borderlands');

    await page.regionField.fillByText('Henderson');

    await page.save();

    await page.new();

    assert.strictEqual(page.regionField.text, 'Henderson');
  });
});
