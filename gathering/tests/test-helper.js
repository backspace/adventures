import { setApplication } from '@ember/test-helpers';
import { start } from 'ember-qunit';
import Application from 'gathering/app';
import config from 'gathering/config/environment';
import PouchDB from 'gathering/utils/pouch';
import MemoryAdapter from 'pouchdb-adapter-memory';
import * as QUnit from 'qunit';
import { setup } from 'qunit-dom';

import 'ember-feature-flags/test-support/helpers/with-feature';

setApplication(Application.create(config.APP));

PouchDB.plugin(MemoryAdapter);

setup(QUnit.assert);

start({ setupTestIsolationValidation: true });
