import Ember from 'ember';
import PouchDB from 'pouchdb';

import Databases from 'adventure-gathering/models/databases';

import config from 'adventure-gathering/config/environment';

export default Ember.Controller.extend({
  databases: Databases.create(),

  actions: {
    sync() {
      this.get('databases').addObject(this.get('destination'));

      const sourceDb = this.container.lookup('adapter:application').get('db');
      const destinationDb = new PouchDB(this.get('destination'), config.emberPouch.options);

      const syncPromise = sourceDb.sync(destinationDb);

      syncPromise.then(result => {
        Ember.run(() => {
          this.set('result', result);
        });
      }).catch(error => {
        Ember.run(() => {
          console.log('error with sync:', error);
          this.set('error', error);
        });
      });

      this.set('syncPromise', syncPromise);
    },

    setDestination(destination) {
      this.set('destination', destination);
    }
  }
});
