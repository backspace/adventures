'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');

module.exports = function(defaults) {
  let app = new EmberApp(defaults, {
    autoImport: {
      alias: {
        fs: 'pdfkit/js/virtual-fs.js',
      },
      webpack: {
        resolve: {
          alias: {
            fs: 'pdfkit/js/virtual-fs.js'
          },
          fallback: {
            assert: require.resolve('assert'),
            stream: require.resolve('stream-browserify'),
            util: require.resolve('util'),
            zlib: require.resolve('browserify-zlib'),
          }
        },
        module: {
          rules: [
            { enforce: 'post', test: /fontkit[/\\]index.js$/, use: [{
              loader: 'transform-loader',
              options: {
                brfs: true
              }
            }] },
            { enforce: 'post', test: /unicode-properties[/\\]index.js$/, use: [{
              loader: 'transform-loader',
              options: {
                brfs: true
              }
            }] },
            { enforce: 'post', test: /linebreak[/\\]src[/\\]linebreaker.js/, use: [{
              loader: 'transform-loader',
              options: {
                brfs: true
              }
            }] },
            { test: /src[/\\]assets/, loader: 'arraybuffer-loader'},
            { test: /\.afm$/, loader: 'raw-loader'}
          ]
        },
      },
    },
    'ember-cli-babel': {
      includePolyfill: true,
    },
    'ember-cli-foundation-6-sass': {
      'foundationJs': 'all'
    },
    fingerprint: {
      exclude: ['apple-touch-icon', 'favicon', 'mstile'],
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

  // FIXME restore draggable number
  // app.import('vendor/jquery.draggableNumber.js');

  return app.toTree();
};
