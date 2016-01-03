import PageObject from '../page-object';

const { clickable, collection, fillable, text, value } = PageObject;

export default PageObject.create({
  visit: clickable('a.sync'),

  enterDestination: fillable('input.destination'),
  destinationValue: value('input.destination'),
  sync: clickable('button.sync'),

  databases: collection({
    itemScope: '.databases .database',

    item: {
      name: text(),
      click: clickable('a')
    }
  }),

  push: {
    scope: 'tr.push',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures')
  },

  pull: {
    scope: 'tr.pull',
    read: text('.read'),
    written: text('.written'),
    writeFailures: text('.write-failures')
  }
});
