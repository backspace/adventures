import PageObject, {
  clickable,
  collection,
  fillable,
  findElement,
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
        return selectElement.find(`option[value=${id}]`).text();
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
      findElement(this, selector).val(id).trigger('change');
    },
  };
};

export default PageObject.create({
  waypoints: collection('[data-test-waypoint]', {
    name: text('[data-test-name]'),
    author: text('[data-test-author]'),
    region: text('[data-test-region]'),

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
  },

  save: clickable('[data-test-save-button]'),
  cancel: clickable('[data-test-cancel-button]'),
  delete: clickable('[data-test-delete-button]'),
});
