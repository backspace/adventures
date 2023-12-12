'use strict';

const EmberApp = require('ember-cli/lib/broccoli/ember-app');
const webpack = require('webpack');

module.exports = function (defaults) {
  const app = new EmberApp(defaults, {
    postcssOptions: {
      compile: {
        plugins: [
          require('tailwindcss')('./tailwind.config.js'),
          { module: require('autoprefixer') },
        ],
      },
    },
    '@embroider/macros': {
      setConfig: {
        '@ember-data/store': {
          polyfillUUID: true,
        },
      },
    },
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
            timers: require.resolve('timers-browserify'),
            tty: require.resolve('tty-browserify'),
            url: false,
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
    fingerprint: {
      exclude: ['apple-touch-icon', 'favicon', 'mstile'],
      replaceExtensions: ['html', 'css', 'js', 'json'],
    },
  });

  return app.toTree();
};
