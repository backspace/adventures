import PageObject, { clickable, collection, text } from 'ember-cli-page-object';

export default PageObject.create({
  visit: clickable('[data-test-sync-route]'),

  destination: {
    scope: '[data-test-destination]',
  },

  sync: clickable('[data-test-sync'),

  databases: collection('[data-test-database]', {
    name: text('[data-test-database-name]'),
    click: clickable('[data-test-database-name]'),
    remove: clickable('[data-test-remove]'),
  }),

  push: {
    scope: '[data-test-push]',
    read: text('[data-test-read]'),
    written: text('[data-test-written]'),
    writeFailures: text('[data-test-write-failures]'),
  },

  pull: {
    scope: '[data-test-pull]',
    read: text('[data-test-read]'),
    written: text('[data-test-written]'),
    writeFailures: text('[data-test-write-failures]'),
  },

  conflicts: collection('[data-test-conflict]'),
});
