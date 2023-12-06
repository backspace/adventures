import { visit, waitUntil } from '@ember/test-helpers';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import page from 'adventure-gathering/tests/pages/destinations';
import nav from 'adventure-gathering/tests/pages/nav';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';

import withSetting from '../helpers/with-setting';

module('Acceptance | destinations', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(async function () {
    const store = this.owner.lookup('service:store');

    const regionOne = store.createRecord('region');
    const regionTwo = store.createRecord('region');
    const regionThree = store.createRecord('region');

    regionOne.set('name', 'There');
    regionTwo.set('name', 'Here');

    await regionOne.save();
    await regionTwo.save();

    const fixtureOne = store.createRecord('destination');

    fixtureOne.setProperties({
      description: 'Hona-Karekh',
      status: 'available',
      region: regionTwo,
      awesomeness: 1,
      updatedAt: new Date(2020, 0, 1),
    });

    await fixtureOne.save();
    await regionTwo.save();

    const fixtureTwo = store.createRecord('destination');

    fixtureTwo.setProperties({
      description: 'Ina-Karekh',
      accessibility: 'You might need help',
      awesomeness: 9,
      risk: 6,
      answer: 'ABC123',
      mask: 'ABC__3',
      credit: 'greatnesses',
      status: 'unavailable',

      region: regionOne,
    });

    await fixtureTwo.save();
    await regionOne.save();

    regionThree.setProperties({
      parent: regionOne,
      name: 'A region within here',
    });

    await regionThree.save();

    await regionOne.save();
  });

  test('existing destinations are listed and can be sorted by region or awesomeness', async function (assert) {
    await visit('/destinations');

    assert.strictEqual(page.destinations[0].description, 'Ina-Karekh');
    assert.strictEqual(page.destinations[0].answer, 'ABC123');
    assert.strictEqual(page.destinations[0].mask, 'ABC__3');
    assert.strictEqual(page.destinations[0].region.text, 'There');
    assert.notOk(page.destinations[0].isIncomplete);

    assert.strictEqual(page.destinations[1].description, 'Hona-Karekh');
    assert.strictEqual(page.destinations[1].region.text, 'Here');
    assert.ok(page.destinations[1].isIncomplete);

    await page.headerRegion.click();

    assert.ok(page.headerRegion.isActive);
    assert.strictEqual(page.destinations[0].description, 'Hona-Karekh');
    assert.strictEqual(page.destinations[1].description, 'Ina-Karekh');

    await page.headerRegion.click();

    assert.notOk(page.headerRegion.isActive);
    assert.strictEqual(page.destinations[0].description, 'Ina-Karekh');
    assert.strictEqual(page.destinations[1].description, 'Hona-Karekh');

    assert.notOk(page.headerAwesomeness.isActive);

    await page.headerAwesomeness.click();

    assert.ok(page.headerAwesomeness.isActive);
    assert.strictEqual(page.destinations[0].description, 'Hona-Karekh');
  });

  test('destination status doesn’t show when the feature flag is off', async function (assert) {
    await visit('/destinations');

    assert.ok(
      page.destinations[0].status.isHidden,
      'expected the status to be hidden'
    );
  });

  test('destination status is displayed and can be toggled from the list when the feature flag is on', async function (assert) {
    await withSetting(this.owner, 'destination-status');
    await visit('/destinations');

    // Sort by region, otherwise destinations will jump around
    await page.headerRegion.click();

    assert.strictEqual(page.destinations[0].status.value, '✓');
    assert.strictEqual(page.destinations[1].status.value, '✘');

    await page.destinations[0].status.click();
    await waitUntil(() => page.destinations[0].status.value === '✘');
    assert.strictEqual(page.destinations[0].status.value, '✘');

    await page.destinations[0].status.click();
    // TODO why does this help?
    await waitUntil(() => page.destinations[0].status.value === '?');
    assert.strictEqual(page.destinations[0].status.value, '?');
  });

  test('a destination can be created and will appear at the top of the list', async function (assert) {
    await withSetting(this.owner, 'clandestine-rendezvous');
    await visit('/destinations');

    await page.new();
    await page.descriptionField.fill('Bromarte');
    await page.answerField.fill('R0E0H0');

    assert.strictEqual(page.suggestedMaskButton.label, 'R_E_H_');

    await page.suggestedMaskButton.click();

    assert.strictEqual(page.maskField.value, 'R_E_H_');

    await page.maskField.fill('R0E0H_');

    await page.save();
    await waitUntil(() => page.destinations.length);

    assert.strictEqual(page.destinations[0].description, 'Bromarte');
    assert.strictEqual(page.destinations[0].mask, 'R0E0H_');
  });

  test('a region can be entered and destinations will be scoped to it', async function (assert) {
    await visit('/destinations');

    await page.destinations[0].region.click();
    assert.strictEqual(page.region.title, 'There');
    assert.strictEqual(page.destinations.length, 1);

    await nav.destinations.click();
    assert.ok(page.region.isHidden);
    assert.strictEqual(page.destinations.length, 2);

    await page.destinations[0].region.click();
    await page.region.leave();
    assert.ok(page.region.isHidden);

    await page.destinations[0].region.click();
    await page.new();
    assert.strictEqual(page.regionField.text, 'There');

    await page.save();
    await waitUntil(() => page.destinations.length);

    assert.strictEqual(page.destinations.length, 2);
  });

  test('the destination’s suggested mask is based on the adventure', async function (assert) {
    await withSetting(this.owner, 'txtbeyond');
    await visit('/destinations');

    await page.new();
    await page.answerField.fill('itchin snitchin witchin');

    assert.strictEqual(
      page.suggestedMaskButton.label,
      'itchin ________ witchin'
    );
  });

  test('unmnemonic devices suggests and requires a mask', async function (assert) {
    await withSetting(this.owner, 'unmnemonic-devices');
    await visit('/destinations');

    await page.new();

    await page.descriptionField.fill('Bromarte');
    await page.answerField.fill('property of comparative literature');
    await page.awesomenessField.fill(10);
    await page.riskField.fill(5);
    await page.regionField.fillByText('There');

    assert.strictEqual(
      page.suggestedMaskButton.label,
      'property __ ___________ literature'
    );

    assert.strictEqual(page.errors.text, 'mask is invalid');

    await page.save();
    await waitUntil(() => page.destinations.length);

    assert.strictEqual(page.destinations[0].description, 'Bromarte');
    assert.ok(page.destinations[0].isIncomplete);

    await page.destinations[0].edit();
    await page.maskField.fill('property of ___________ __________');

    assert.ok(page.errors.isHidden);

    await page.save();
    await waitUntil(() => page.destinations.length);

    assert.strictEqual(
      page.destinations[0].mask,
      'property of ___________ __________'
    );
    assert.notOk(page.destinations[0].isIncomplete);
  });

  test('the status fieldset doesn’t show when the feature isn’t on', async function (assert) {
    await visit('/destinations');

    await page.destinations[0].edit();

    assert.ok(
      page.statusFieldset.isHidden,
      'expected the status fieldset to be hidden'
    );
  });

  test('a destination can be edited and edits can be cancelled', async function (assert) {
    await withSetting(this.owner, 'destination-status');
    await visit('/destinations');

    await page.destinations[0].edit();

    assert.strictEqual(page.descriptionField.value, 'Ina-Karekh');
    assert.strictEqual(page.accessibilityField.value, 'You might need help');
    assert.strictEqual(page.awesomenessField.value, '9');
    assert.strictEqual(page.riskField.value, '6');
    assert.strictEqual(page.answerField.value, 'ABC123');
    assert.strictEqual(page.creditField.value, 'greatnesses');
    assert.strictEqual(page.regionField.text, 'There');

    await page.descriptionField.fill('Kisua');
    await page.accessibilityField.fill('You must cross the Empty Thousand!');
    await page.awesomenessField.fill(10);
    await page.riskField.fill(5);
    await page.answerField.fill('DEF456');
    await page.creditField.fill('excellences');
    await page.statusFieldset.availableOption.click();
    await page.save();
    await waitUntil(() => page.destinations.length);

    const destination = page.destinations[0];
    assert.strictEqual(destination.description, 'Kisua');
    assert.strictEqual(destination.awesomeness, '10');
    assert.strictEqual(destination.status.value, '✓');
    assert.strictEqual(destination.risk, '5');

    await page.destinations[0].edit();

    assert.strictEqual(
      page.accessibilityField.value,
      'You must cross the Empty Thousand!'
    );
    assert.strictEqual(page.answerField.value, 'DEF456');
    assert.strictEqual(page.creditField.value, 'excellences');

    await page.descriptionField.fill('Banbarra');
    await page.cancel();

    assert.strictEqual(page.destinations[0].description, 'Kisua');
  });

  test('a new destination defaults to the same region as the previously-created one', async function (assert) {
    await page.visit();
    await page.new();
    await page.descriptionField.fill('Borderlands');

    await page.regionField.fillByText('There');

    assert.deepEqual(page.regionField.options.mapBy('text'), [
      '',
      'Here',
      'There',
      '--A region within here',
    ]);

    await page.save();

    await page.new();

    assert.strictEqual(page.regionField.text, 'There');
  });

  test('a destination can be deleted', async function (assert) {
    await page.visit();

    await page.destinations[0].edit();
    await page.delete();
    await waitUntil(() => page.destinations.length);

    assert.strictEqual(page.destinations.length, 1);
  });
});
