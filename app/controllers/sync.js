import Ember from 'ember';
import PouchDB from 'pouchdb';

import { task } from 'ember-concurrency';

import Databases from 'adventure-gathering/models/databases';

import config from 'adventure-gathering/config/environment';

import stringify from 'npm:json-stringify-safe';

export default Ember.Controller.extend({
  databases: Databases.create(),

  isSyncing: false,

  version: config.APP.version,

  sync: task(function * () {
    this.get('databases').addObject(this.get('destination'));

    const sourceDb = Ember.getOwner(this).lookup('adapter:application').get('db');
    const destinationDb = new PouchDB(this.get('destination'), config.emberPouch.options);

    const syncPromise = sourceDb.sync(destinationDb);

    this.set('result', undefined);
    this.set('syncPromise', syncPromise);

    yield syncPromise.then(result => {
      Ember.run(() => {
        this.set('result', result);
      });
    }).catch(error => {
      Ember.run(() => {
        console.log('error with sync:');
        console.log(stringify(error));
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
