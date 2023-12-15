import PageObject, {
  clickable,
  collection,
  fillable,
  hasClass,
  text,
  value,
  visitable,
} from 'ember-cli-page-object';
import { findOne } from 'ember-cli-page-object/extend';

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

  regions: collection('.region', {
    name: text('.name'),
    hours: text('[data-test-hours]'),
    isIncomplete: hasClass('incomplete'),
    nesting: nesting('.name'),

    edit: clickable('.edit'),
  }),

  new: clickable('.regions.new'),

  nameField: {
    scope: 'input.name',
    value: value(),
    fill: fillable(),
  },

  notesField: {
    scope: 'textarea.notes',
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

  save: clickable('.save'),
  cancel: clickable('.cancel'),
  delete: clickable('.delete'),
});
