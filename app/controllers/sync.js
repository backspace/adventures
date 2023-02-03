import { run } from '@ember/runloop';
import { getOwner } from '@ember/application';
import Controller from '@ember/controller';
import PouchDB from 'adventure-gathering/utils/pouch';

import { task } from 'ember-concurrency';

import Databases from 'adventure-gathering/models/databases';

import config from 'adventure-gathering/config/environment';

import stringify from 'json-stringify-safe';

export default Controller.extend({
  databases: Databases.create(),

  isSyncing: false,

  version: config.APP.version,

  sync: task(function * () {
    this.get('databases').addObject(this.get('destination'));

    const sourceDb = getOwner(this).lookup('adapter:application').get('db');
    const destinationDb = new PouchDB(this.get('destination'), config.emberPouch.options);

    const syncPromise = sourceDb.sync(destinationDb);

    this.set('result', undefined);
    this.set('syncPromise', syncPromise);

    yield syncPromise.then(result => {
      run(() => {
        this.set('result', result);
      });
    }).catch(error => {
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
    }
  }
});
