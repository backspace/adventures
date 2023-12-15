import PageObject, { clickable, collection, text } from 'ember-cli-page-object';

export default PageObject.create({
  visit: clickable('a.sync'),

  destination: {
    scope: 'input.destination',
  },

  sync: clickable('button.sync'),

  databases: collection('.databases .database', {
    name: text('[data-test-database-name]'),
    click: clickable('[data-test-database-name]'),
    remove: clickable('[data-test-remove]'),
  }),

  push: {
    scope: 'tr.push',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures'),
  },

  pull: {
    scope: 'tr.pull',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures'),
  },
});
