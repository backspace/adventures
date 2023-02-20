/*jshint node:true*/
'use strict';

module.exports = function (/* environment, appConfig */) {
  // See https://github.com/san650/ember-web-app#documentation for a list of
  // supported properties

  return {
    name: 'adventure-gathering',
    short_name: 'adventure-gathering',
    description: '',
    start_url: '/',
    display: 'standalone',
    background_color: '#fff',
    theme_color: '#fff',
    icons: [
      {
        src: '/favicon.png',
        sizes: '300x300',
        type: 'image/png',
      },
    ],
  };
};
