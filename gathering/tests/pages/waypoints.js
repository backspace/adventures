import PageObject, {
  clickable,
  collection,
  fillable,
  hasClass,
  text,
  value,
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

  nameField: {
    scope: '[data-test-name-field]',
    value: value(),
    fill: fillable(),
  },

  authorField: {
    scope: '[data-test-author-field]',
    value: value(),
    fill: fillable(),
  },

  callField: {
    scope: '[data-test-call-field]',
    value: value(),
    fill: fillable(),
  },

  creditField: {
    scope: '[data-test-credit-field]',
    value: value(),
    fill: fillable(),
  },

  outlineField: textField('[data-test-outline-container]'),

  excerptField: {
    scope: '[data-test-excerpt-field]',
    value: value(),
    fill: fillable(),
  },

  pageField: {
    scope: '[data-test-page-field]',
    value: value(),
    fill: fillable(),
  },

  dimensionsField: {
    scope: '[data-test-dimensions-field]',
    value: value(),
    fill: fillable(),
  },

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
