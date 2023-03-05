import { hasMany, belongsTo, attr } from '@ember-data/model';
import { computed } from '@ember/object';
import { sort } from '@ember/object/computed';
import Model from 'ember-pouch/model';

export default Model.extend({
  destination: belongsTo('destination'),
  teams: hasMany('team', { async: false }),

  sortedTeams: sort('teams', 'teamSort'),
  teamSort: Object.freeze(['name']),

  isForbidden: computed('teams.@each.meetings', function () {
    const teams = this.teams;
    const meetingCounts = teams.mapBy('meetings.length');

    return meetingCounts.uniq().length !== 1;
  }),

  index: attr('number'),
  offset: attr('number'),

  phone: attr('string'),

  createdAt: attr('createDate'),
  updatedAt: attr('updateDate'),
});
