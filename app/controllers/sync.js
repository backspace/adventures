import { getOwner } from '@ember/application';
import Controller from '@ember/controller';
import { run } from '@ember/runloop';
import config from 'adventure-gathering/config/environment';
import PouchDB from 'adventure-gathering/utils/pouch';

import { task } from 'ember-concurrency';

import { storageFor } from 'ember-local-storage';

import stringify from 'json-stringify-safe';

export default Controller.extend({
  databases: storageFor('databases'),

  isSyncing: false,

  version: config.APP.version,

  sync: task(function* () {
    this.databases.addObject(this.destination);

    const sourceDb = getOwner(this).lookup('adapter:application').get('db');
    const destinationDb = new PouchDB(
      this.destination,
      config.emberPouch.options
    );

    const syncPromise = sourceDb.sync(destinationDb);

    this.set('result', undefined);
    this.set('syncPromise', syncPromise);

    yield syncPromise
      .then((result) => {
        run(() => {
          this.set('result', result);
        });
      })
      .catch((error) => {
        run(() => {
          // eslint-disable-next-line
          console.log('error with sync:', stringify(error));
          this.set('error', error);
        });
      });
  }),

  actions: {
    setDestination(destination) {
      this.set('destination', destination);
    },
  },
});
