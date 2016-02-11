import Ember from 'ember';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  hasMany
} = DS;

export default Model.extend({
  name: attr('string'),
  notes: attr('string'),

  destinations: hasMany('destination', {async: false}),

  meetingCount: Ember.computed('destinations.@each.meetings', function() {
    return this.get('destinations').mapBy('meetings.length').reduce((prev, curr) => prev + curr);
  }),

  x: attr('number'),
  y: attr('number'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
