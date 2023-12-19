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

  outlineField: {
    scope: '[data-test-outline-field]',
    value: value(),
    fill: fillable(),
    isInvalid: hasClass('border-red-500'),
    errors: text('[data-test-outline-container] [data-test-errors]', {
      resetScope: true,
    }),
  },

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

  // FIXME add validation
  regionField: {
    scope: '[data-test-region]',
    value: value(),
    text: selectText(),
    fillByText: fillSelectByText(),
    select: selectable(),
  },

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
