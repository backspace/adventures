import { hasMany, belongsTo, attr } from '@ember-data/model';
import Model from 'ember-pouch/model';
import sortBy from 'lodash.sortby';
import uniq from 'lodash.uniq';

export default class Meeting extends Model {
  @belongsTo('destination', { inverse: 'meetings', async: false })
  destination;

  @belongsTo('waypoint', { inverse: 'meetings', async: false })
  waypoint;

  @hasMany('team', { inverse: 'meetings', async: false })
  teams;

  @attr('number')
  index;

  @attr('number')
  offset;

  @attr('string')
  phone;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  get sortedTeams() {
    return sortBy(this.teams, 'name');
  }

  get isForbidden() {
    const teams = this.teams;
    const meetingCounts = teams.map((t) => t.meetings.length);

    return uniq(meetingCounts).length !== 1;
  }
}
