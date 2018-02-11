import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr } = DS;

export default Model.extend({
  goal: attr('string'),

  destinationStatus: attr('boolean'),

  clandestineRendezvous: attr('boolean'),
  txtbeyond: attr('boolean')
});
