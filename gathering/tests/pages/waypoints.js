import PageObject, {
  clickable,
  collection,
  hasClass,
  text,
} from 'ember-cli-page-object';

import selectField from './helpers/select-field';
import textField from './helpers/text-field';

export default PageObject.create({
  region: {
    scope: '[data-test-waypoint-region-scope]',

    title: text('[data-test-title]'),
    leave: clickable('[data-test-leave]'),
  },

  headerRegion: {
    scope: '[data-test-header-region]',
    click: clickable(),
    isActive: hasClass('bg-black'),
  },

  waypoints: collection('[data-test-waypoint]', {
    name: text('[data-test-name]'),
    author: text('[data-test-author]'),
    region: { scope: '[data-test-region]' },

    isIncomplete: hasClass('border-x-red-500'),

    status: {
      scope: '[data-test-status]',
      value: text(),
      click: clickable(),
    },

    edit: clickable('[data-test-edit]'),
  }),

  new: clickable('[data-test-waypoints-new]'),

  nameField: textField('[data-test-name-container]'),
  authorField: textField('[data-test-author-container]'),
  callField: textField('[data-test-call-container]'),
  creditField: textField('[data-test-credit-container]'),
  outlineField: textField('[data-test-outline-container]'),
  excerptField: textField('[data-test-excerpt-container]', 'textarea'),
  pageField: textField('[data-test-page-container]'),
  dimensionsField: textField('[data-test-dimensions-container]'),

  regionField: selectField('[data-test-region-container]'),

  statusFieldset: {
    scope: '[data-test-status-fieldset]',

    availableOption: {
      scope: 'input[value=available]',
      click: clickable(),
    },
  },

  save: clickable('[data-test-save-button]'),
  cancel: clickable('[data-test-cancel-button]'),
  delete: clickable('[data-test-delete-button]'),
});
