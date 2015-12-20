import Ember from 'ember';
import PouchDB from 'pouchdb';

import config from 'adventure-gathering/config/environment';

export default Ember.Controller.extend({
  actions: {
    sync() {
      const sourceDb = this.container.lookup('adapter:application').get('db');
      const destinationDb = new PouchDB(this.get('destination'), config.emberPouch.options);

      const syncPromise = sourceDb.sync(destinationDb);

      syncPromise.then(result => {
        Ember.run(() => {
          this.set('result', result);
        });
      }).catch(error => {
        Ember.run(() => {
          this.set('error', JSON.stringify(error));
        });
      });

      this.set('syncPromise', syncPromise);
    }
  }
});
