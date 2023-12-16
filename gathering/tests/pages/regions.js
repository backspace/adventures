import PageObject, {
  clickable,
  collection,
  fillable,
  text,
  value,
  visitable,
} from 'ember-cli-page-object';
import { findOne } from 'ember-cli-page-object/extend';

import hasAttribute from './has-attribute';

const nesting = function (selector) {
  return {
    isDescriptor: true,

    get() {
      let nestingClass = Array.from(findOne(this, selector).classList).find(
        (klass) => klass.startsWith('pl-')
      );

      if (nestingClass) {
        let number = parseInt(nestingClass.replace('pl-', ''));
        return (number - 2) / 3;
      }
    },
  };
};

export default PageObject.create({
  visit: visitable('/regions'),
  visitMap: clickable('a.map'),

  regions: collection('[data-test-region]', {
    name: text('[data-test-name]'),
    hours: text('[data-test-hours]'),
    isIncomplete: hasAttribute('[data-test-incomplete]'),
    nesting: nesting('[data-test-name]'),

    edit: clickable('[data-test-edit]'),
  }),

  new: clickable('[data-test-regions-new]'),

  nameField: {
    scope: '[data-test-name-field]',
    value: value(),
    fill: fillable(),
  },

  notesField: {
    scope: '[data-test-notes-field]',
    value: value(),
  },

  accessibilityField: {
    scope: '[data-test-accessibility-field]',
    value: value(),
    fill: fillable(),
  },

  hoursField: {
    scope: '[data-test-hours-field]',
    value: value(),
    fill: fillable(),
  },

  save: clickable('[data-test-save]'),
  cancel: clickable('[data-test-cancel]'),
  delete: clickable('[data-test-delete]'),
});
