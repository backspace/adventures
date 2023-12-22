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
import { TrackedArray } from 'tracked-built-ins';

export default class SyncController extends Controller {
  @storageFor('databases')
  databases;

  @tracked destination;
  @tracked result;
  @tracked error;

  @tracked conflicts;

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

    /*
    const changes = sourceDb
      .changes({ live: true, include_docs: true, conflicts: true })
      .on('change', (info) => {
        if (info.doc._conflicts) {
          console.log('confl???', info);
          this.conflicts.push(info.doc);
        }
      })
      .on('error', (error) => {
        console.log('error with changes:', stringify(error));
        this.error = error;
      });
    */

    const syncPromise = sourceDb.sync(destinationDb, { conflicts: true });
    // .on('error', (error) => {
    //   console.log('error with sync:', stringify(error));
    //   this.error = error;
    // })
    // .on('change', (info) => {
    //   console.log('change with sync:', stringify(info));
    //   this.result = info;
    // });

    this.result = undefined;
    this.syncPromise = syncPromise;
    this.conflicts = new TrackedArray();

    try {
      let result = yield syncPromise;
      this.result = result;

      let allDocs = yield sourceDb.allDocs({
        include_docs: true,
        conflicts: true,
      });

      allDocs.rows.forEach((row) => {
        if (row.doc._conflicts) {
          this.conflicts.push(row.doc);
        }
      });
    } catch (error) {
      console.log('error with sync:', stringify(error));
      this.error = error;
    }

    // changes.cancel();
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
