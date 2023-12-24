/*jshint node:true*/
'use strict';

module.exports = function (/* environment, appConfig */) {
  // See https://github.com/san650/ember-web-app#documentation for a list of
  // supported properties

  return {
    name: 'gathering',
    short_name: 'Gathering',
    description: 'data gathering for adventures',
    start_url: '/',
    scope: '/',
    display: 'standalone',
    background_color: '#fff',
    theme_color: '#1779ba',
    icons: [
      {
        src: '/favicon.png',
        sizes: '300x300',
        type: 'image/png',
      },
    ],
  };
};
