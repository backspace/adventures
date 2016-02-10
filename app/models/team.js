import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr, hasMany } = DS;

export default Model.extend({
  name: attr('string'),
  users: attr('string'),
  riskAversion: attr('number'),
  notes: attr('string'),

  meetings: hasMany('meeting', {async: false}),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
