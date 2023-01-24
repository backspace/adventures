import config from 'adventure-gathering/config/environment';
import PouchDB from 'ember-pouch/pouchdb';

export default function clearDatabase(hooks) {
  hooks.beforeEach(async function() {
    return new PouchDB(config.emberPouch.localDb).destroy();
  });
}
