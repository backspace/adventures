import classic from 'ember-classic-decorator';
import { computed } from '@ember/object';
import { inject as service } from '@ember/service';
import Model from 'ember-pouch/model';
import DS from 'ember-data';

const { attr, hasMany } = DS;

@classic
export default class Region extends Model {
  @attr('string')
  name;

  @attr('string')
  notes;

  @hasMany('destination', { async: false })
  destinations;

  @computed('destinations.@each.meetings')
  get allMeetings() {
    return this.get('destinations').mapBy('meetings').flat();
  }

  @computed('destinations.@each.meetings', 'allMeetings.length')
  get meetingCount() {
    console.log(
      `meeting count ${this.get('name')}`,
      this.get('destinations')
        .mapBy('meetings.length')
        .reduce((prev, curr) => prev + curr)
    );
    return this.get('allMeetings.length');
  }

  @attr('number')
  x;

  @attr('number')
  y;

  @attr('createDate')
  createdAt;

  @attr('updateDate')
  updatedAt;

  @service
  features;

  @service
  pathfinder;

  @computed('pathfinder.regions.[]')
  get hasPaths() {
    return this.get('pathfinder').hasRegion(this.get('name'));
  }

  @computed('hasPaths')
  get isComplete() {
    if (this.get('features.txtbeyond')) {
      return this.get('hasPaths');
    } else {
      return true;
    }
  }
}
