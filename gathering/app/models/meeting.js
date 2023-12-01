import { sort } from '@ember/object/computed';
import { hasMany, belongsTo, attr } from '@ember-data/model';
import Model from 'ember-pouch/model';
import classic from 'ember-classic-decorator';

@classic
export default class Meeting extends Model {
  @belongsTo('destination', { inverse: 'meetings', async: false })
  destination;

  @belongsTo('waypoint', { inverse: 'meetings', async: false })
  waypoint;

  @hasMany('team', { inverse: 'meetings', async: false })
  teams;

  @sort('teams', 'teamSort')
  sortedTeams;

  teamSort = Object.freeze(['name']);

  get isForbidden() {
    const teams = this.teams;
    const meetingCounts = teams.map((t) => t.meetings.length);

    return meetingCounts.uniq().length !== 1;
  }

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
}
