import { visit } from '@ember/test-helpers';
import { all } from 'rsvp';
import { run } from '@ember/runloop';
import { module, test } from 'qunit';
import { setupApplicationTest } from 'ember-qunit';
import withSetting from '../helpers/with-setting';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';

import page from '../pages/destinations';

module('Acceptance | destinations', function(hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function(assert) {
    const store = this.owner.lookup('service:store');
    const done = assert.async();

    run(() => {
      const regionOne = store.createRecord('region');
      const regionTwo = store.createRecord('region');

      regionOne.set('name', 'There');
      regionTwo.set('name', 'Here');

      all([regionOne.save(), regionTwo.save()]).then(() => {
        const fixtureOne = store.createRecord('destination');
        const fixtureTwo = store.createRecord('destination');

        fixtureOne.setProperties({
          description: 'Ina-Karekh',
          accessibility: 'You might need help',
          awesomeness: 9,
          risk: 6,
          answer: 'ABC123',
          mask: 'ABC__3',
          status: 'unavailable',

          region: regionOne
        });

        fixtureTwo.setProperties({
          description: 'Hona-Karekh',
          status: 'available',
          region: regionTwo
        });

        return all([fixtureTwo.save(), fixtureOne.save()]);
      }).then(() => {
        return all([regionOne.save(), regionTwo.save()]);
      }).then(() => {
        done();
      });
    });
  });

  test('existing destinations are listed and can be sorted by region or awesomeness', async function(assert) {
    await visit('/destinations');

    assert.equal(page.destinations[0].description, 'Ina-Karekh');
    assert.equal(page.destinations[0].answer, 'ABC123');
    assert.equal(page.destinations[0].mask, 'ABC__3');
    assert.equal(page.destinations[0].region, 'There');
    assert.notOk(page.destinations[0].isIncomplete);

    assert.equal(page.destinations[1].description, 'Hona-Karekh');
    assert.equal(page.destinations[1].region, 'Here');
    assert.ok(page.destinations[1].isIncomplete);

    await page.headerRegion.click();

    assert.equal(page.destinations[0].description, 'Hona-Karekh');
    assert.equal(page.destinations[1].description, 'Ina-Karekh');

    await page.headerRegion.click();

    assert.equal(page.destinations[0].description, 'Ina-Karekh');
    assert.equal(page.destinations[1].description, 'Hona-Karekh');

    await page.headerAwesomeness.click();

    assert.equal(page.destinations[0].description, 'Hona-Karekh');
  });

  test('destination status doesn’t show when the feature flag is off', async function(assert) {
    await visit('/destinations');

    assert.ok(page.destinations[0].status.isHidden, 'expected the status to be hidden');
  });

  test('destination status is displayed and can be toggled from the list when the feature flag is on', async function(assert) {
    await withSetting(this.owner, 'destination-status');
    await visit('/destinations');

    // Sort by region, otherwise destinations will jump around
    await page.headerRegion.click();

    assert.equal(page.destinations[0].status.value, '✓');
    assert.equal(page.destinations[1].status.value, '✘');

    await page.destinations[0].status.click();
    await page.destinations[1].status.click();

    assert.equal(page.destinations[0].status.value, '✘');
    assert.equal(page.destinations[1].status.value, '?');
  });

  test('a destination can be created and will appear at the top of the list', async function(assert) {
    await withSetting(this.owner, 'clandestine-rendezvous');
    await visit('/destinations');

    await page.new();
    await page.descriptionField.fill('Bromarte');
    await page.answerField.fill('R0E0H0');

    assert.equal(page.suggestedMaskButton.label, 'R_E_H_');

    await page.suggestedMaskButton.click();

    assert.equal(page.maskField.value, 'R_E_H_');

    await page.maskField.fill('R0E0H_');

    await page.save();

    assert.equal(page.destinations[0].description, 'Bromarte');
    assert.equal(page.destinations[0].mask, 'R0E0H_');
  });

  test('the destination’s suggested mask is based on the adventure', async function(assert) {
    await withSetting(this.owner, 'txtbeyond');
    await visit('/destinations');

    await page.new();
    await page.answerField.fill('itchin snitchin witchin');

    assert.equal(page.suggestedMaskButton.label, 'itchin ________ witchin');
  });

  test('the status fieldset doesn’t show when the feature isn’t on', async function(assert) {
    await visit('/destinations');

    await page.destinations[0].edit();

    assert.ok(page.statusFieldset.isHidden, 'expected the status fieldset to be hidden');
  });

  test('a destination can be edited and edits can be cancelled', async function(assert) {
    await withSetting(this.owner, 'destination-status');
    await visit('/destinations');

    await page.destinations[0].edit();

    assert.equal(page.descriptionField.value, 'Ina-Karekh');
    assert.equal(page.accessibilityField.value, 'You might need help');
    assert.equal(page.awesomenessField.value, '9');
    assert.equal(page.riskField.value, '6');
    assert.equal(page.answerField.value, 'ABC123');
    assert.equal(page.regionField.text, 'There');

    await page.descriptionField.fill('Kisua');
    await page.accessibilityField.fill('You must cross the Empty Thousand!');
    await page.awesomenessField.fill(10);
    await page.riskField.fill(5);
    await page.answerField.fill('DEF456');
    await page.statusFieldset.availableOption.click();
    await page.save();

    const destination = page.destinations[0];
    assert.equal(destination.description, 'Kisua');
    assert.equal(destination.awesomeness, '10');
    assert.equal(destination.status.value, '✓');
    assert.equal(destination.risk, '5');

    await page.destinations[0].edit();

    assert.equal(page.accessibilityField.value, 'You must cross the Empty Thousand!');
    assert.equal(page.answerField.value, 'DEF456');

    await page.descriptionField.fill('Banbarra');
    await page.cancel();

    assert.equal(page.destinations[0].description, 'Kisua');
  });

  test('a new destination defaults to the same region as the previously-created one', async function(assert) {
    await page.visit();
    await page.new();
    await page.descriptionField.fill('Borderlands');

    await page.regionField.fillByText('There');

    await page.save();

    await page.new();

    assert.equal(page.regionField.text, 'There');
  });

  test('a destination can be deleted', async function (assert) {
    await page.visit();

    await page.destinations[0].edit();
    await page.delete();

    assert.equal(page.destinations.length, 1);
  });
});
