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

  destinations: collection('.destination', {
    description: text('.description'),
    answer: text('.answer'),
    awesomeness: text('.awesomeness'),
    risk: text('.risk'),
    mask: text('.mask'),

    isIncomplete: hasClass('border-x-red-500'),
    hasMeetings: hasClass('meetings'),

    region: { scope: '[data-test-destination-region]' },

    status: {
      scope: '.status',
      value: text(),
      click: clickable(),
    },

    edit: clickable('.edit'),
  }),

  new: clickable('.destinations.new'),

  descriptionField: {
    scope: 'textarea.description',
    value: value(),
    fill: fillable(),
  },

  accessibilityField: {
    scope: 'textarea.accessibility',
    value: value(),
    fill: fillable(),
  },

  awesomenessField: {
    scope: 'input.awesomeness',
    value: value(),
    fill: fillable(),
  },

  riskField: {
    scope: 'input.risk',
    value: value(),
    fill: fillable(),
  },

  answerField: {
    scope: 'input.answer',
    value: value(),
    fill: fillable(),
  },

  maskField: {
    scope: 'input.mask',
    value: value(),
    fill: fillable(),
  },

  suggestedMaskButton: {
    scope: 'button.suggested-mask',
    label: text(),
    click: clickable(),
  },

  creditField: {
    scope: '[data-test-credit]',
    value: value(),
    fill: fillable(),
  },

  regionField: {
    scope: 'select.region',
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable(),
    options: collection('option'),
  },

  statusFieldset: {
    scope: 'fieldset.status',

    availableOption: {
      scope: 'input[value=available]',
      click: clickable(),
    },
  },

  errors: {
    scope: '[data-test-errors]',
  },

  save: clickable('.save'),
  cancel: clickable('.cancel'),
  delete: clickable('.delete'),
});
