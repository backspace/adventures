import { visit } from '@ember/test-helpers';

import { setupApplicationTest } from 'ember-qunit';

import { module, test } from 'qunit';

import page from '../pages/sync';

module('Acceptance | sync', function (hooks) {
  setupApplicationTest(hooks);

  hooks.beforeEach(async function () {
    const store = this.owner.lookup('service:store');

    const fixture = store.createRecord('destination');
    fixture.set('description', 'Ina-Karekh');

    await fixture.save();
  });

  // I had these as separate tests but localStorage was bleeding through… ugh
  test('can sync with another database, syncs are remembered and can be returned to and removed', async function (assert) {
    localStorage.clear();
    localStorage.setItem('storage:databases', JSON.stringify(['old-db', null]));

    await visit('/');
    await page.visit();

    assert.strictEqual(page.databases.length, 1);
    assert.strictEqual(page.databases[0].name, 'old-db');
    assert.strictEqual(page.destination.value, 'old-db');

    await page.destination.fillIn('sync-db');
    await page.sync();

    const syncController = this.owner.lookup('controller:sync');
    await syncController.get('syncPromise');

    assert.strictEqual(page.push.read, '2');
    assert.strictEqual(page.push.written, '2');
    assert.strictEqual(page.push.writeFailures, '0');

    assert.strictEqual(page.pull.read, '0');
    assert.strictEqual(page.pull.written, '0');
    assert.strictEqual(page.pull.writeFailures, '0');

    assert.strictEqual(page.databases.length, 2);

    await page.destination.fillIn('other-sync');
    await page.sync();

    assert.strictEqual(page.databases.length, 3);
    assert.strictEqual(page.databases[0].name, 'other-sync');
    assert.strictEqual(page.databases[1].name, 'sync-db');

    await page.databases[1].click();

    assert.strictEqual(page.destination.value, 'sync-db');

    await page.databases[2].remove();

    assert.strictEqual(page.databases.length, 2);
  });
});
