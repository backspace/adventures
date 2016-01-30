import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  belongsTo,
  hasMany
} = DS;

export default Model.extend({
  destination: belongsTo('destination'),
  teams: hasMany('team'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
