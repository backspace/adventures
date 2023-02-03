import { assert } from '@ember/debug';
import { isEmpty } from '@ember/utils';
import { Adapter } from 'ember-pouch';
import PouchDB from 'adventure-gathering/utils/pouch';
import config from 'adventure-gathering/config/environment';
import Ember from 'ember';

window.process = window.process || {};
window.global = window;

function createDb() {
  let localDb = config.emberPouch.localDb;

  assert('emberPouch.localDb must be set', !isEmpty(localDb));

  if (Ember.testing) {
    localDb += new Date().getMilliseconds();
  }

  let db = new PouchDB(localDb, config.emberPouch.options);

  if (config.emberPouch.remoteDb) {
    let remoteDb = new PouchDB(config.emberPouch.remoteDb);

    db.sync(remoteDb, {
      live: true,
      retry: true
    });
  }

  return db;
}

export default Adapter.extend({
  init() {
    this._super(...arguments);
    this.set('db', createDb());
  }
});
