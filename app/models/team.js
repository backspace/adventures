import { hasMany, attr } from '@ember-data/model';
import { computed } from '@ember/object';
import { mapBy, filterBy } from '@ember/object/computed';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
export default class Team extends Model {
  @attr('string')
  name;

  @attr('string')
  users;

  @attr('number')
  riskAversion;

  @attr('string')
  notes;

  @attr()
  phones;

  @hasMany('meeting', { async: false })
  meetings;

  @mapBy('meetings', 'destination')
  destinations;

  @filterBy('meetings', 'isNew', false)
  savedMeetings;

  @computed('destinations.@each.awesomeness')
  get averageAwesomeness() {
    const awesomenesses = this.destinations
      .mapBy('awesomeness')
      .filter((a) => a);

    if (awesomenesses.length > 0) {
      return (
        awesomenesses.reduce((prev, curr) => prev + curr) / awesomenesses.length
      );
    }

    return 0;
  }

  @computed('destinations.@each.risk')
  get averageRisk() {
    const risks = this.destinations.mapBy('risk').filter((r) => r);

    if (risks.length > 0) {
      return risks.reduce((prev, curr) => prev + curr) / risks.length;
    }

    return 0;
  }

  @computed('phones.[]')
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
}
