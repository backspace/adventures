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

const nesting = function () {
  return {
    isDescriptor: true,

    get() {
      let nestingClass = Array.from(findOne(this).classList).find((klass) =>
        klass.startsWith('nesting-')
      );

      if (nestingClass) {
        let number = nestingClass.replace('nesting-', '');
        return parseInt(number);
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
    nesting: nesting(),

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
