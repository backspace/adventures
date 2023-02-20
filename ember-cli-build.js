'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const nodeSass = require('node-sass');
const webpack = require('webpack');

module.exports = function (defaults) {
  let app = new EmberApp(defaults, {
    autoImport: {
      webpack: {
        plugins: [
          new webpack.ProvidePlugin({
            Buffer: ['buffer', 'Buffer'],
            process: 'process/browser',
          }),
        ],
        resolve: {
          alias: {
            fs: 'pdfkit/js/virtual-fs.js',
            'iconv-lite': false,
          },
          fallback: {
            crypto: false,
            assert: require.resolve('assert'),
            Buffer: require.resolve('buffer/'),
            buffer: require.resolve('buffer/'),
            stream: require.resolve('stream-browserify'),
            util: require.resolve('util'),
            zlib: require.resolve('browserify-zlib'),
          },
        },
        module: {
          rules: [
            { test: /src[/\\]assets/, loader: 'arraybuffer-loader' },
            { test: /\.afm$/, type: 'asset/source' },
            // bundle and load binary files inside static-assets folder as base64
            {
              test: /src[/\\]static-assets/,
              type: 'asset/inline',
              generator: {
                dataUrl: (content) => {
                  return content.toString('base64');
                },
              },
            },
            // load binary files inside lazy-assets folder as an URL
            {
              test: /src[/\\]lazy-assets/,
              type: 'asset/resource',
            },
            // convert to base64 and include inline file system binary files used by fontkit and linebreak
            {
              enforce: 'post',
              test: /fontkit[/\\]index.js$/,
              loader: 'transform-loader',
              options: {
                brfs: {},
              },
            },
            {
              enforce: 'post',
              test: /linebreak[/\\]src[/\\]linebreaker.js/,
              loader: 'transform-loader',
              options: {
                brfs: {},
              },
            },
          ],
        },
      },
    },
    'ember-cli-babel': {
      includePolyfill: true,
    },
    'ember-cli-foundation-6-sass': {
      foundationJs: 'all',
    },
    fingerprint: {
      exclude: ['apple-touch-icon', 'favicon', 'mstile'],
      replaceExtensions: ['html', 'css', 'js', 'json'],
    },
    sassOptions: {
      implementation: nodeSass,
    },
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
