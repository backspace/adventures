import PageObject, {
  clickable,
  fillable,
  property,
  value,
  visitable,
} from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/settings'),

  goalField: {
    scope: '[data-test-goal]',
    value: value(),
    fill: fillable(),
  },

  destinationStatus: {
    scope: '[data-test-destination-status]',

    isChecked: property('checked'),
  },

  clandestineRendezvous: {
    scope: '[data-test-clandestine-rendezvous]',

    isChecked: property('checked'),
  },

  txtbeyond: {
    scope: '[data-test-txtbeyond]',

    isChecked: property('checked'),
  },

  unmnemonicDevices: {
    scope: '[data-test-unmnemonic-devices]',

    isChecked: property('checked'),
  },

  saveButton: {
    scope: '[data-test-save-button]',
    isDisabled: property('disabled'),
  },

  cancel: clickable('.cancel'),
});
