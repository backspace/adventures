import { computed } from '@ember/object';
import { mapBy } from '@ember/object/computed';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr, hasMany } = DS;

export default Model.extend({
  name: attr('string'),
  users: attr('string'),
  riskAversion: attr('number'),
  notes: attr('string'),

  meetings: hasMany('meeting', {async: false}),

  destinations: mapBy('meetings', 'destination'),

  averageAwesomeness: computed('destinations.@each.awesomeness', function() {
    const awesomenesses = this.get('destinations').mapBy('awesomeness').filter(a => a);

    if (awesomenesses.length > 0) {
      return awesomenesses.reduce((prev, curr) => prev + curr)/awesomenesses.length;
    }
  }),

  averageRisk: computed('destinations.@each.risk', function() {
    const risks = this.get('destinations').mapBy('risk').filter(r => r);

    if (risks.length > 0) {
      return risks.reduce((prev, curr) => prev + curr)/risks.length;
    }
  }),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
