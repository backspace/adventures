import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { htmlSafe } from '@ember/template';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { ref } from 'ember-ref-bucket';

// FIXME not used but needed by Foundation??
// eslint-disable-next-line
import jQuery from 'jquery';

export default class MappableRegionComponent extends Component {
  @service puzzles;

  @ref('Region') regionElement;
  @tracked originalPosition;

  get draggable() {
    if (this.args.draggable === false) {
      return false;
    }

    return true;
  }

  get style() {
    return htmlSafe(
      `top: ${Math.max(this.args.region.y, 0)}px;` +
        `left: ${Math.max(this.args.region.x, 0)}px;`
    );
  }

  get meetingIndex() {
    const regionId = this.args.region.id;
    const highlightedTeam = this.args.highlightedTeam;

    if (highlightedTeam) {
      const meetingRegionIds = highlightedTeam
        .hasMany('meetings')
        .value()
        .rejectBy('isNew')
        .map((meeting) => meeting.belongsTo('destination').value())
        .map((destination) => destination.belongsTo('region').value())
        .mapBy('id');
      const index = meetingRegionIds.indexOf(regionId);

      if (index > -1) {
        return index + 1;
      } else {
        return undefined;
      }
    } else {
      return undefined;
    }
  }

  get waypointMeetingIndex() {
    if (!this.puzzles.implementation.hasWaypoints) {
      return undefined;
    }

    const regionId = this.args.region.id;
    const highlightedTeam = this.args.highlightedTeam;

    if (highlightedTeam) {
      const waypointMeetingRegionIds = highlightedTeam
        .hasMany('meetings')
        .value()
        .rejectBy('isNew')
        .filterBy('waypoint')
        .map((meeting) => meeting.belongsTo('waypoint').value())
        .map((waypoint) => waypoint.belongsTo('region').value())
        .mapBy('id');
      const index = waypointMeetingRegionIds.indexOf(regionId);

      if (index > -1) {
        return index + 1;
      } else {
        return undefined;
      }
    } else {
      return undefined;
    }
  }

  @action
  dragStart({ clientX, clientY, offsetX }) {
    if (!this.draggable) {
      return;
    }

    // Adding the offset removes a corresponding horizontal shift when dropping. Unclear why it doesn’t happen vertically.
    this.originalPosition = {
      x: clientX + offsetX,
      y: clientY,
    };
  }

  @action
  dragEnd({ clientX, clientY }) {
    if (!this.draggable) {
      return;
    }

    const x = this.args.region.x;
    const y = this.args.region.y;

    this.args.region.x = x + (clientX - this.originalPosition.x);
    this.args.region.y = y + (clientY - this.originalPosition.y);

    this.args.region.save();
  }

  @action
  click() {
    this.args.sidebarRegionElement?.scrollIntoView();
  }
}
