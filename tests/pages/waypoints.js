import PageObject, {
  clickable,
  collection,
  fillable,
  text,
  value,
} from 'ember-cli-page-object';

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

  save: clickable('[data-test-save-button]'),
  cancel: clickable('[data-test-cancel-button]'),
  delete: clickable('[data-test-delete-button]'),
});
