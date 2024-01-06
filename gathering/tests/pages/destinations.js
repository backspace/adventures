import PageObject, {
  clickable,
  collection,
  hasClass,
  text,
  visitable,
} from 'ember-cli-page-object';

import hasAttribute from './helpers/has-attribute';
import selectField from './helpers/select-field';
import textField from './helpers/text-field';

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
    entireRegion: { scope: '[data-test-destination-entire-region]' },

    status: {
      scope: '[data-test-status]',
      value: text(),
      click: clickable(),
    },

    edit: clickable('[data-test-edit]'),
  }),

  new: clickable('[data-test-destinations-new]'),

  regionField: selectField('[data-test-region-container]'),

  descriptionField: textField('[data-test-description-container]', 'textarea'),
  accessibilityField: textField(
    '[data-test-accessibility-container]',
    'textarea',
  ),
  awesomenessField: textField('[data-test-awesomeness-container]'),
  riskField: textField('[data-test-risk-container]'),
  answerField: textField('[data-test-answer-container]'),

  maskField: textField('[data-test-mask-container]'),

  suggestedMaskButton: {
    scope: '[data-test-suggested-mask]',
    label: text(),
    click: clickable(),
  },

  creditField: textField('[data-test-credit-container]'),

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
