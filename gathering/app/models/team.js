import { hasMany, attr } from '@ember-data/model';
import Model from 'ember-pouch/model';
import truncate from 'lodash.truncate';

export default class Team extends Model {
  @attr('string')
  name;

  @attr('string')
  users;

  @attr('number')
  riskAversion;

  @attr('string')
  notes;

  @attr('string')
  identifier;

  @attr()
  phones;

  @hasMany('meeting', { inverse: 'teams', async: false })
  meetings;

  get destinations() {
    return this.meetings.map((m) => m.destination);
  }

  get waypoints() {
    return this.meetings.map((m) => m.waypoint);
  }

  get savedMeetings() {
    return this.meetings.filter((m) => !m.isNew);
  }

  get averageAwesomeness() {
    const awesomenesses = this.meetings
      .map((m) => m.destination)
      .filter((d) => d)
      .map((d) => d.awesomeness)
      .filter((a) => a);

    if (awesomenesses.length > 0) {
      return (
        awesomenesses.reduce((prev, curr) => prev + curr) / awesomenesses.length
      );
    }

    return 0;
  }

  get averageRisk() {
    const risks = this.meetings
      .map((m) => m.destination)
      .filter((d) => d)
      .map((d) => d.risk)
      .filter((r) => r);

    if (risks.length > 0) {
      return risks.reduce((prev, curr) => prev + curr) / risks.length;
    }

    return 0;
  }

  get highestRecommendedRisk() {
    switch (this.riskAversion) {
      case 3:
        return 10;
      case 2:
        return 7;
      case 1:
      default:
        return 4;
    }
  }

  get phonesString() {
    return (this.phones || [])
      .map((phone) => {
        return `${phone.number}: ${phone.displaySize}`;
      })
      .join(', ');
  }

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  get truncatedName() {
    return truncate(this.name, {
      length: 40,
      separator: /,? +/,
      omission: '…',
    });
  }
}
