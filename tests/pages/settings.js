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
    scope: 'input.goal',
    value: value(),
    fill: fillable(),
  },

  destinationStatus: {
    scope: 'input.destination-status',

    isChecked: property('checked'),
  },

  clandestineRendezvous: {
    scope: 'input.clandestine-rendezvous',

    isChecked: property('checked'),
  },

  txtbeyond: {
    scope: 'input.txtbeyond',

    isChecked: property('checked'),
  },

  save: clickable('.save'),
  cancel: clickable('.cancel'),
});
