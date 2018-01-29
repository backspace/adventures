'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
  let app = new EmberApp(defaults, {
    'ember-cli-babel': {
      includePolyfill: true,
    },
    fingerprint: {
      replaceExtensions: ['html', 'css', 'js', 'json']
    }
  });

  // Use `app.import` to add additional libraries to the generated
  // output files.
  //
  // If you need to use different assets in different
  // environments, specify an object as the first parameter. That
  // object's keys should be the environment name and the values
  // should be the asset to use in that environment.
  //
  // If the library that you are including contains AMD or ES6
  // modules that you would like to import into your application
  // please specify an object with the list of modules as keys
  // along with the exports of each module as its value.

  var path = require('path');
  app.import({test: path.join(app.bowerDirectory, 'pouchdb/dist/pouchdb.memory.js')});

  app.import('vendor/jquery.draggableNumber.js');

  // FIXME remove unnecessary import outside test environment
  // Test-specific packages cannot be imported with ember-browserify
  // https://github.com/ef4/ember-browserify/issues/14
  app.import(path.join(app.bowerDirectory, 'tinycolor/tinycolor.js'));

  return app.toTree();
};
