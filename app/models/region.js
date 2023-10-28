import { computed } from '@ember/object';
import { inject as service } from '@ember/service';
import { belongsTo, hasMany, attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import Model from 'ember-pouch/model';

@classic
export default class Region extends Model {
  @attr('string')
  name;

  @attr('string')
  hours;

  @attr('string')
  accessibility;

  @attr('string')
  notes;

  @belongsTo('region', { inverse: 'children', async: false })
  parent;

  @hasMany('region', { inverse: 'parent', async: false })
  children;

  @hasMany('destination', { async: false })
  destinations;

  @hasMany('waypoint', { async: false })
  waypoints;

  @computed('destinations.@each.meetings')
  get allMeetings() {
    return this.destinations.mapBy('meetings').flat();
  }

  @computed('allMeetings.length', 'destinations.@each.meetings', 'name')
  get meetingCount() {
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

  @computed('parent.nesting')
  get nesting() {
    if (this.parent) {
      return this.parent.nesting + 1;
    } else {
      return 0;
    }
  }

  @computed('parent')
  get ancestor() {
    let current = this;

    while (current.belongsTo('parent').value()) {
      current = current.belongsTo('parent').value();
    }

    return current;
  }
}
