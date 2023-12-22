import { run } from '@ember/runloop';
import { visit, waitUntil } from '@ember/test-helpers';

import PouchDB from 'adventure-gathering/utils/pouch';
import { setupApplicationTest } from 'ember-qunit';

import { module, test } from 'qunit';

import regionsPage from '../pages/regions';
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

  test('shows when there are conflicts', async function (assert) {
    let store = this.owner.lookup('service:store');

    let region = store.createRecord('region', {
      name: 'A region',
    });

    await region.save();

    await visit('/');
    await page.visit();
    await page.destination.fillIn('eventual-conflicts');
    await page.sync();

    let otherDb = new PouchDB('eventual-conflicts', {
      adapter: 'memory',
    });

    let regionDoc = (await otherDb.allDocs()).rows.find((row) =>
      row.id.includes('region'),
    );

    await otherDb.put({
      _id: regionDoc.id,
      _rev: regionDoc.value.rev,
      name: 'A region version 100',
    });

    await regionsPage.visit();

    await regionsPage.regions[0].edit();
    await regionsPage.nameField.fill('A region version -100');
    await regionsPage.save();
    await waitUntil(() => regionsPage.regions.length);

    await page.visit();
    await page.sync();

    assert.strictEqual(page.conflicts.length, 1);
  });
});
