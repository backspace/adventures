import { getOwner } from '@ember/application';
import Controller from '@ember/controller';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import config from 'gathering/config/environment';
import PouchDB from 'gathering/utils/pouch';

import { task } from 'ember-concurrency';

import { storageFor } from 'ember-local-storage';

import stringify from 'json-stringify-safe';

export default class SyncController extends Controller {
  @storageFor('databases')
  databases;

  @tracked destination;
  @tracked result;
  @tracked error;

  @tracked syncPromise;
  @tracked isSyncing = false;

  version = config.APP.version;

  get sortedDatabases() {
    return Array.from(this.databases.filter((d) => d)).toReversed();
  }

  @task(function* () {
    this.databases.removeObject(this.destination);
    this.databases.addObject(this.destination);

    const sourceDb = getOwner(this).lookup('adapter:application').get('db');
    const destinationDb = new PouchDB(
      this.destination,
      config.emberPouch.options,
    );

    const syncPromise = sourceDb.sync(destinationDb);

    this.result = undefined;
    this.syncPromise = syncPromise;

    try {
      let result = yield syncPromise;

      this.result = result;
    } catch (error) {
      console.log('error with sync:', stringify(error));
      this.error = error;
    }
  })
  sync;

  @action
  handleDestinationInput(event) {
    this.destination = event.target.value;
  }

  @action
  setDestination(destination) {
    this.destination = destination;
  }

  @action
  removeDestination(destination) {
    this.databases.removeObject(destination);
  }
}
