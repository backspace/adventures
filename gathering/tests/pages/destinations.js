import { fillIn } from '@ember/test-helpers';
import PageObject, {
  clickable,
  collection,
  fillable,
  findElement,
  hasClass,
  selectable,
  text,
  value,
  visitable,
} from 'ember-cli-page-object';

import hasAttribute from './helpers/has-attribute';

const selectText = function (selector) {
  return {
    isDescriptor: true,

    get() {
      const selectElement = findElement(this, selector);
      const id = selectElement.val();

      if (id) {
        return selectElement.find(`option[value=${id}]`).text().trim();
      } else {
        return '';
      }
    },
  };
};

const fillSelectByText = function (selector) {
  return {
    isDescriptor: true,

    value(text) {
      const selectElement = findElement(this, selector);
      const id = selectElement.find(`option:contains('${text}')`).attr('value');
      return fillIn(selectElement[0], id);
    },
  };
};

export default PageObject.create({
  visit: visitable('/destinations'),

  region: {
    scope: '[data-test-destination-region-scope]',

    title: text('[data-test-title]'),
    leave: clickable('[data-test-leave]'),
  },

  headerRegion: {
    scope: '[data-test-header-region]',
    click: clickable(),
    isActive: hasClass('bg-black'),
  },

  headerAwesomeness: {
    scope: '[data-test-header-awesomeness]',
    click: clickable(),
    isActive: hasClass('bg-black'),
  },

  destinations: collection('[data-test-destination]', {
    description: text('[data-test-description]'),
    answer: text('[data-test-answer]'),
    awesomeness: text('[data-test-awesomeness]'),
    risk: text('[data-test-risk]'),
    mask: text('[data-test-mask]'),

    isIncomplete: hasClass('border-x-red-500'),
    hasMeetings: hasAttribute('[data-test-has-meetings]'),

    region: { scope: '[data-test-destination-region]' },

    status: {
      scope: '[data-test-status]',
      value: text(),
      click: clickable(),
    },

    edit: clickable('[data-test-edit]'),
  }),

  new: clickable('[data-test-destinations-new]'),

  descriptionField: {
    scope: '[data-test-description]',
    value: value(),
    fill: fillable(),
  },

  accessibilityField: {
    scope: '[data-test-accessibility]',
    value: value(),
    fill: fillable(),
  },

  awesomenessField: {
    scope: '[data-test-awesomeness]',
    value: value(),
    fill: fillable(),
  },

  riskField: {
    scope: '[data-test-risk]',
    value: value(),
    fill: fillable(),
  },

  answerField: {
    scope: '[data-test-answer]',
    value: value(),
    fill: fillable(),
  },

  maskField: {
    scope: '[data-test-mask]',
    value: value(),
    fill: fillable(),
  },

  suggestedMaskButton: {
    scope: '[data-test-suggested-mask]',
    label: text(),
    click: clickable(),
  },

  creditField: {
    scope: '[data-test-credit]',
    value: value(),
    fill: fillable(),
  },

  regionField: {
    scope: '[data-test-region]',
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable(),
    options: collection('option'),
  },

  statusFieldset: {
    scope: '[data-test-status]',

    availableOption: {
      scope: 'input[value=available]',
      click: clickable(),
    },
  },

  errors: {
    scope: '[data-test-errors]',
  },

  save: clickable('[data-test-save]'),
  cancel: clickable('[data-test-cancel]'),
  delete: clickable('[data-test-delete]'),
});
