import PageObject, {
  clickable,
  fillable,
  is,
  value,
  visitable
} from 'ember-cli-page-object';

export default PageObject.create({
  visit: visitable('/settings'),

  goalField: {
    scope: 'input.goal',
    value: value(),
    fill: fillable()
  },

  destinationStatus: {
    scope: 'input.destination-status',

    isChecked: is(':checked')
  },

  clandestineRendezvous: {
    scope: 'input.clandestine-rendezvous',

    isChecked: is(':checked')
  },

  txtbeyond: {
    scope: 'input.txtbeyond',

    isChecked: is(':checked')
  },

  save: clickable('.save'),
  cancel: clickable('.cancel')
});
