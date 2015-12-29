import Ember from 'ember';
import PouchDB from 'pouchdb';

import Databases from 'adventure-gathering/models/databases';

import config from 'adventure-gathering/config/environment';

import stringify from 'npm:json-stringify-safe';

export default Ember.Controller.extend({
  databases: Databases.create(),

  isSyncing: false,

  actions: {
    sync() {
      this.get('databases').addObject(this.get('destination'));

      const sourceDb = this.container.lookup('adapter:application').get('db');
      const destinationDb = new PouchDB(this.get('destination'), config.emberPouch.options);

      const syncPromise = sourceDb.sync(destinationDb);

      this.set('isSyncing', true);

      syncPromise.then(result => {
        Ember.run(() => {
          if (!this.isDestroyed) {
            this.set('result', result);
            this.set('isSyncing', false);
          }
        });
      }).catch(error => {
        Ember.run(() => {
          console.log('error with sync:');
          console.log(stringify(error));
          this.set('error', error);
          this.set('isSyncing', false);
        });
      });

      this.set('syncPromise', syncPromise);
    },

    setDestination(destination) {
      this.set('destination', destination);
    }
  }
});
