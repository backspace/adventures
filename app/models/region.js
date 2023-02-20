import { computed } from '@ember/object';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';
import DS from 'ember-data';
import Model from 'ember-pouch/model';

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
    return this.destinations.mapBy('meetings').flat();
  }

  @computed('allMeetings.length', 'destinations.@each.meetings', 'name')
  get meetingCount() {
    console.log(
      `meeting count ${this.name}`,
      this.destinations
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

  @computed('name', 'pathfinder.regions.[]')
  get hasPaths() {
    return this.pathfinder.hasRegion(this.name);
  }

  @computed('features.txtbeyond', 'hasPaths')
  get isComplete() {
    if (this.get('features.txtbeyond')) {
      return this.hasPaths;
    } else {
      return true;
    }
  }
}
