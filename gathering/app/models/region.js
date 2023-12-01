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

  @hasMany('destination', { inverse: 'region', async: false })
  destinations;

  @hasMany('waypoint', { inverse: 'region', async: false })
  waypoints;

  get meetingCount() {
    let destinationMeetingCount = this.destinations.reduce(
      (sum, destination) => {
        return sum + destination.meetingCount;
      },
      0
    );

    return this.children.reduce((sum, child) => {
      return sum + child.meetingCount;
    }, destinationMeetingCount);
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

  get hasPaths() {
    return this.pathfinder.hasRegion(this.name);
  }

  get isComplete() {
    // eslint-disable-next-line ember/no-get
    if (this.get('features.txtbeyond')) {
      return this.hasPaths;
    } else {
      return true;
    }
  }

  get nesting() {
    if (this.parent) {
      return this.parent.nesting + 1;
    } else {
      return 0;
    }
  }

  get ancestor() {
    let current = this;

    while (current.belongsTo('parent').value()) {
      current = current.belongsTo('parent').value();
    }

    return current;
  }

  get survey() {
    let availableCount = 0;
    let unavailableCount = 0;
    let unknownCount = 0;

    this.hasMany('destinations')
      .value()
      .forEach((d) => {
        if (d.status === 'available') {
          availableCount++;
        } else if (d.status === 'unavailable') {
          unavailableCount++;
        } else {
          unknownCount++;
        }
      });

    (this.hasMany('children').value() || []).forEach((c) => {
      let childSurvey = c.survey;

      availableCount += childSurvey.availableCount;
      unavailableCount += childSurvey.unavailableCount;
      unknownCount += childSurvey.unknownCount;
    });

    return {
      availableCount,
      unavailableCount,
      unknownCount,
    };
  }

  get surveyString() {
    let survey = this.survey;
    return `D ?${survey.unknownCount} ✓${survey.availableCount} ✘${survey.unavailableCount}`;
  }

  get surveyIncomplete() {
    return this.survey && this.survey.unknownCount > 0;
  }
}
