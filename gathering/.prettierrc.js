'use strict';

module.exports = {
  plugins: ['prettier-plugin-ember-template-tag'],
  overrides: [
    {
      files: '**/*.{hbs,js,ts,gjs,gts}',
      options: {
        singleQuote: true,
      },
    },
  ],
};
