import { computed } from '@ember/object';
import Model from 'ember-pouch/model';
import DS from 'ember-data';
import { inject as service } from '@ember/service';

const {
  attr,
  hasMany
} = DS;

export default Model.extend({
  name: attr('string'),
  notes: attr('string'),

  destinations: hasMany('destination', {async: false}),

  meetingCount: computed('destinations.@each.meetings', function() {
    return this.get('destinations').mapBy('meetings.length').reduce((prev, curr) => prev + curr);
  }),

  x: attr('number'),
  y: attr('number'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate'),

  features: service(),
  pathfinder: service(),

  hasPaths: computed('pathfinder.regions.[]', function() {
    return this.get('pathfinder').hasRegion(this.get('name'));
  }),

  isComplete: computed('hasPaths', function() {
    if (this.get('features.txtbeyond')) {
      return this.get('hasPaths');
    } else {
      return true;
    }
  })
});
