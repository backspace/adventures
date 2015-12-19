import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr
} = DS;

export default Model.extend({
  description: attr('string'),
  accessibility: attr('string'),

  awesomeness: attr('number'),
  risk: attr('number')
});
