import { run } from '@ember/runloop';

import { test } from 'qunit';
import moduleForAcceptance from 'adventure-gathering/tests/helpers/module-for-acceptance';

import stringify from 'npm:json-stringify-safe';

import page from '../pages/sync';

moduleForAcceptance('Acceptance | sync', {
  beforeEach(assert) {
    const store = this.application.__container__.lookup('service:store');
    const done = assert.async();

    run(() => {
      const fixture = store.createRecord('destination');

      fixture.set('description', 'Ina-Karekh');

      fixture.save().then(() => {
        done();
      });
    });
  }
});

// I had these as separate tests but localStorage was bleeding through… ugh
test('can sync with another database, syncs are remembered and can be returned to', function(assert) {
  const done = assert.async();

  visit('/');
  page.visit();

  page.enterDestination('sync-db').sync();

  andThen(() => {
    const syncController = this.application.__container__.lookup('controller:sync');

    syncController.get('syncPromise').then(() => {
      assert.equal(page.push().read(), '1');
      assert.equal(page.push().written(), '1');
      assert.equal(page.push().writeFailures(), '0');

      // FIXME the sync db is accumulating documents
      //assert.equal(page.pull().read(), '0');
      //assert.equal(page.pull().written(), '0');
      assert.equal(page.pull().writeFailures(), '0');

      assert.equal(page.databases().count(), 1);

      page.enterDestination('other-sync').sync();

      andThen(() => {
        assert.equal(page.databases().count(), 2);
        assert.equal(page.databases(1).name(), 'sync-db');
        assert.equal(page.databases(2).name(), 'other-sync');
      });

      page.databases(1).click();

      andThen(() => {
        assert.equal(page.destinationValue(), 'sync-db');

        done();
      });
    }).catch((error) => {
      assert.ok(false, 'expected no errors syncing');

      // FIXME had to add this because PhantomJS was timing out during this test;
      // the test PouchDB was full and producing errors. Should figure out how
      // to destroy the database next time this happens.
      console.log(stringify(error));

      done();
    });
  });
});
