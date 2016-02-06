import Ember from 'ember';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  belongsTo,
  hasMany
} = DS;

export default Model.extend({
  description: attr('string'),
  accessibility: attr('string'),

  answer: attr('string'),
  mask: attr('string'),

  suggestedMask: Ember.computed('answer', function() {
    return (this.get('answer') || '').replace(/\d/g, '_');
  }),

  awesomeness: attr('number'),
  risk: attr('number'),

  isComplete: Ember.computed('description', 'answer', 'awesomeness', 'risk', function() {
    const {description, answer, awesomeness, risk} = this.getProperties('description', 'answer', 'awesomeness', 'risk');

    return !Ember.isEmpty(description) &&
      !Ember.isEmpty(answer) &&
      awesomeness > 0 &&
      !Ember.isEmpty(risk);
  }),

  isIncomplete: Ember.computed.not('isComplete'),

  status: attr('string'),

  isAvailable: Ember.computed.equal('status', 'available'),

  region: belongsTo('region', {async: false}),

  meetings: hasMany('meeting'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
