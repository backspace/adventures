import { setApplication } from '@ember/test-helpers';
import Application from 'adventure-gathering/app';
import config from 'adventure-gathering/config/environment';
import PouchDB from 'adventure-gathering/utils/pouch';
import { start } from 'ember-qunit';
import MemoryAdapter from 'pouchdb-adapter-memory';
import * as QUnit from 'qunit';
import { setup } from 'qunit-dom';

import 'ember-feature-flags/test-support/helpers/with-feature';

setApplication(Application.create(config.APP));

PouchDB.plugin(MemoryAdapter);

setup(QUnit.assert);

start();
