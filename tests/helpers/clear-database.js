import config from 'adventure-gathering/config/environment';
import PouchDB from 'pouchdb';

export default function clearDatabase(hooks) {
  hooks.beforeEach(async function() {
    return new PouchDB(config.emberPouch.localDb).destroy();
  });
}
