import { run } from '@ember/runloop';
import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';
import { setupApplicationTest } from 'ember-qunit';
import { module, test } from 'qunit';

import page from '../pages/settings';

module('Acceptance | settings', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function () {
    this.store = this.owner.lookup('service:store');
  });

  test('a new settings document can be created and saved', async function (assert) {
    const done = assert.async();

    await page.visit();

    assert.equal(page.goalField.value, '');
    assert.notOk(page.destinationStatus.isChecked);

    await page.goalField.fill('abc');
    await page.clandestineRendezvous.click();
    await page.txtbeyond.click();
    await page.save();

    this.store.findRecord('settings', 'settings').then((settings) => {
      assert.equal(settings.get('goal'), 'abc');
      assert.ok(settings.get('clandestineRendezvous'));
      assert.ok(settings.get('txtbeyond'));
      done();
    });
  });
});

module('Acceptance | settings', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function (assert) {
    this.store = this.owner.lookup('service:store');
    const done = assert.async();

    run(() => {
      const settings = this.store.createRecord('settings', {
        id: 'settings',
        goal: '12345',
        destinationStatus: true,
      });

      settings.save().then(() => {
        done();
      });
    });
  });

  test('an existing settings document is displayed and can be updated, with its boolean flags mirrored to the features service', async function (assert) {
    const done = assert.async();

    await page.visit();

    const featuresService = this.owner.lookup('service:features');
    assert.ok(featuresService.get('destinationStatus'));

    assert.equal(page.goalField.value, '12345');
    assert.ok(page.destinationStatus.isChecked);

    await page.goalField.fill('789');
    await page.destinationStatus.click();
    await page.clandestineRendezvous.click();
    await page.txtbeyond.click();
    await page.save();

    this.store.findRecord('settings', 'settings').then((settings) => {
      const featuresService = this.owner.lookup('service:features');
      assert.notOk(featuresService.get('destinationStatus'));
      assert.ok(featuresService.get('clandestineRendezvous'));
      assert.ok(featuresService.get('txtbeyond'));

      assert.equal(settings.get('goal'), '789');
      assert.notOk(settings.get('destinationStatus'));

      done();
    });
  });
});
