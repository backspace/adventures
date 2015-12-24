import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr
} = DS;

export default Model.extend({
  description: attr('string'),
  accessibility: attr('string'),

  answer: attr('string'),

  awesomeness: attr('number'),
  risk: attr('number'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
