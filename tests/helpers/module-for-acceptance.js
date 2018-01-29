import { module } from 'qunit';
import { resolve } from 'rsvp';
import startApp from '../helpers/start-app';
import destroyApp from '../helpers/destroy-app';

import PouchDB from 'pouchdb';
import config from 'adventure-gathering/config/environment';

export default function(name, options = {}) {
  module(name, {
    beforeEach(assert) {
      const done = assert.async();

      new PouchDB(config.emberPouch.localDb).destroy().then(() => {
        this.application = startApp();

        if (options.beforeEach) {
          options.beforeEach.apply(this, arguments);
        }

        done();
      });
    },

    afterEach() {
      let afterEach = options.afterEach && options.afterEach.apply(this, arguments);
      return resolve(afterEach).then(() => destroyApp(this.application));
    }
  });
}
