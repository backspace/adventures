import { action } from '@ember/object';
import { htmlSafe } from '@ember/template';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { ref } from 'ember-ref-bucket';

// FIXME not used but needed by Foundation??
// eslint-disable-next-line
import jQuery from 'jquery';

export default class MappableRegionComponent extends Component {
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

  @action
  dragStart() {
    if (!this.draggable) {
      return;
    }

    // Not adding the height causes the region to be off by its height?!
    this.originalPosition = {
      x: this.regionElement.offsetLeft,
      y: this.regionElement.offsetHeight + this.regionElement.offsetTop,
    };
  }

  @action
  dragEnd({ pageX, pageY }) {
    if (!this.draggable) {
      return;
    }

    const x = this.args.region.x;
    const y = this.args.region.y;

    this.args.region.x = x + (pageX - this.originalPosition.x);
    this.args.region.y = y + (pageY - this.originalPosition.y);

    this.args.region.save();
  }

  @action
  click() {
    this.args.sidebarRegionElement?.scrollIntoView();
  }
}
