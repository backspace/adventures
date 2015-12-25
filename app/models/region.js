import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  hasMany
} = DS;

export default Model.extend({
  name: attr('string'),
  notes: attr('string'),

  destinations: hasMany('destination'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
