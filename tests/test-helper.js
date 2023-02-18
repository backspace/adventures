import Application from 'adventure-gathering/app';
import config from 'adventure-gathering/config/environment';
import { setApplication } from '@ember/test-helpers';
import { start } from 'ember-qunit';
import PouchDB from 'adventure-gathering/utils/pouch';
import MemoryAdapter from "pouchdb-adapter-memory";

import 'ember-feature-flags/test-support/helpers/with-feature';

setApplication(Application.create(config.APP));

PouchDB.plugin(MemoryAdapter);

start();
