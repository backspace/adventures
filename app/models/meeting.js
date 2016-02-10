import Ember from 'ember';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const {
  attr,
  belongsTo,
  hasMany
} = DS;

export default Model.extend({
  destination: belongsTo('destination'),
  teams: hasMany('team', {async: false}),

  isForbidden: Ember.computed('teams.@each.meetings', function() {
    const teams = this.get('teams');
    const meetingCounts = teams.mapBy('meetings.length');

    return meetingCounts.uniq().length !== 1;
  }),

  index: attr('number'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate')
});
