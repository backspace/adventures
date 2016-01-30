import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr, hasMany } = DS;

export default Model.extend({
  name: attr('string'),
  users: attr('string'),
  riskAversion: attr('number'),

  meetings: hasMany('meeting'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
