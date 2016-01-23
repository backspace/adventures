import Ember from 'ember';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  belongsTo
} = DS;

export default Model.extend({
  description: attr('string'),
  accessibility: attr('string'),

  answer: attr('string'),

  awesomeness: attr('number'),
  risk: attr('number'),

  status: attr('string'),

  isAvailable: Ember.computed.equal('status', 'available'),

  region: belongsTo('region'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
