import { module } from 'qunit';
import startApp from '../helpers/start-app';
import destroyApp from '../helpers/destroy-app';

import PouchDB from 'pouchdb';
import config from 'adventure-gathering/config/environment';

export default function(name, options = {}) {
  module(name, {
    beforeEach() {
      return new PouchDB(config.emberPouch.localDb).destroy().then(() => {
        this.application = startApp();

        if (options.beforeEach) {
          options.beforeEach.apply(this, arguments);
        }
      });
    },

    afterEach() {
      destroyApp(this.application);

      if (options.afterEach) {
        options.afterEach.apply(this, arguments);
      }
    }
  });
}
