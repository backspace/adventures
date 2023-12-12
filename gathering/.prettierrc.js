'use strict';

module.exports = {
  plugins: [
    'prettier-plugin-ember-template-tag',
    'prettier-plugin-tailwindcss',
  ],
  overrides: [
    {
      files: '**/*.{hbs,js,ts,gjs,gts}',
      options: {
        singleQuote: true,
      },
    },
  ],
};
