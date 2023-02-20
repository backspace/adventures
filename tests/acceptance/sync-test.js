import { visit } from '@ember/test-helpers';
import { run } from '@ember/runloop';

import { module, test } from 'qunit';
import { setupApplicationTest } from 'ember-qunit';

import clearDatabase from 'adventure-gathering/tests/helpers/clear-database';

import stringify from 'json-stringify-safe';

import page from '../pages/sync';

module('Acceptance | sync', function (hooks) {
  setupApplicationTest(hooks);
  clearDatabase(hooks);

  hooks.beforeEach(function (assert) {
    const store = this.owner.lookup('service:store');
    const done = assert.async();

    run(() => {
      const fixture = store.createRecord('destination');

      fixture.set('description', 'Ina-Karekh');

      fixture.save().then(() => {
        done();
      });
    });
  });

  // I had these as separate tests but localStorage was bleeding through… ugh
  test('can sync with another database, syncs are remembered and can be returned to', async function (assert) {
    localStorage.clear();
    localStorage.setItem('storage:databases', JSON.stringify(['old-db']));

    const done = assert.async();

    await visit('/');
    await page.visit();

    assert.equal(page.databases.length, 1);
    assert.equal(page.databases[0].name, 'old-db');

    await page.enterDestination('sync-db').sync();

    const syncController = this.owner.lookup('controller:sync');

    syncController
      .get('syncPromise')
      .then(async () => {
        assert.equal(page.push.read, '2');
        assert.equal(page.push.written, '2');
        assert.equal(page.push.writeFailures, '0');

        assert.equal(page.pull.read, '0');
        assert.equal(page.pull.written, '0');
        assert.equal(page.pull.writeFailures, '0');

        assert.equal(page.databases.length, 2);

        await page.enterDestination('other-sync').sync();

        assert.equal(page.databases.length, 3);
        assert.equal(page.databases[1].name, 'sync-db');
        assert.equal(page.databases[2].name, 'other-sync');

        await page.databases[1].click();

        assert.equal(page.destinationValue, 'sync-db');

        done();
      })
      .catch((error) => {
        assert.ok(false, 'expected no errors syncing');

        // FIXME had to add this because PhantomJS was timing out during this test;
        // the test PouchDB was full and producing errors. Should figure out how
        // to destroy the database next time this happens.
        // eslint-disable-next-line
        console.log(stringify(error));

        done();
      });
  });
});
