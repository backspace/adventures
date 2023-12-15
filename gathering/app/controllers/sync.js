import { getOwner } from '@ember/application';
import Controller from '@ember/controller';
import { action } from '@ember/object';
import { run } from '@ember/runloop';
import { tracked } from '@glimmer/tracking';
import config from 'adventure-gathering/config/environment';
import PouchDB from 'adventure-gathering/utils/pouch';

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
      config.emberPouch.options
    );

    const syncPromise = sourceDb.sync(destinationDb);

    this.result = undefined;
    this.syncPromise = syncPromise;

    yield syncPromise
      .then((result) => {
        run(() => {
          this.result = result;
        });
      })
      .catch((error) => {
        run(() => {
          console.log('error with sync:', stringify(error));
          this.error = error;
        });
      });
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
