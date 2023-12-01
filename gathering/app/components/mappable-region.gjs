import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { htmlSafe } from '@ember/template';
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { ref } from 'ember-ref-bucket';
import createRef from 'ember-ref-bucket/modifiers/create-ref';
import { and } from 'ember-truth-helpers';

// FIXME not used but needed by Foundation??
// eslint-disable-next-line
import jQuery from 'jquery';

export default class MappableRegionComponent extends Component {
  @service puzzles;

  @ref('Region') regionElement;
  @tracked originalPosition;

  @tracked moving;
  @tracked unsavedX;
  @tracked unsavedY;

  get draggable() {
    if (this.args.draggable === false) {
      return false;
    }

    return true;
  }

  get style() {
    if (this.moving && this.unsavedX && this.unsavedY) {
      return htmlSafe(`top: ${this.unsavedY}px;` + `left: ${this.unsavedX}px;`);
    } else {
      return htmlSafe(
        `top: ${Math.max(this.args.region.y, 0)}px;` +
          `left: ${Math.max(this.args.region.x, 0)}px;`
      );
    }
  }

  get meetingIndex() {
    const regionId = this.args.region.ancestor.id;
    const highlightedTeam = this.args.highlightedTeam;

    if (highlightedTeam) {
      const meetingAncestorRegionIds = highlightedTeam
        .hasMany('meetings')
        .value()
        .filter((m) => !m.isNew)
        .map((meeting) => meeting.belongsTo('destination').value())
        .map(
          (destination) => destination.belongsTo('region').value().ancestor.id
        );

      const index = meetingAncestorRegionIds.indexOf(regionId);

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

    const regionId = this.args.region.ancestor.id;
    const highlightedTeam = this.args.highlightedTeam;

    if (highlightedTeam) {
      const waypointMeetingAncestorRegionIds = highlightedTeam
        .hasMany('meetings')
        .value()
        .filter((m) => !m.isNew && m.waypoint)
        .map((meeting) => meeting.belongsTo('waypoint').value())
        .map((waypoint) => waypoint.belongsTo('region').value().ancestor.id);

      const index = waypointMeetingAncestorRegionIds.indexOf(regionId);

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
  dragStart(e) {
    if (!this.draggable) {
      return;
    }

    let { clientX, clientY } = e;

    this.unsavedX = undefined;
    this.unsavedY = undefined;

    this.originalPosition = {
      x: clientX,
      y: clientY,
    };

    this.moving = true;

    document.addEventListener('mousemove', this.drag);
  }

  @action
  drag({ clientX, clientY }) {
    if (!this.draggable || !this.moving) {
      return;
    }

    this.unsavedX = this.args.region.x + clientX - this.originalPosition.x;
    this.unsavedY = this.args.region.y + clientY - this.originalPosition.y;
  }

  @action
  dragEnd({ clientX, clientY }) {
    if (!this.draggable) {
      return;
    }

    const x = this.args.region.x;
    const y = this.args.region.y;

    this.args.region.x = Math.max(0, x + (clientX - this.originalPosition.x));
    this.args.region.y = Math.max(0, y + (clientY - this.originalPosition.y));

    this.moving = false;

    document.removeEventListener('mousemove', this.drag);

    this.args.region.save();
  }

  @action
  click() {
    this.args.sidebarRegionElement?.scrollIntoView();
  }

  <template>
    {{! template-lint-disable no-inline-styles }}
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class='region
        {{if @isHighlighted "highlighted"}}
        {{if (and @survey @region.surveyIncomplete) "incomplete"}}
        {{if this.moving "moving"}}'
      style={{this.style}}
      {{on 'click' this.click}}
      {{! template-lint-disable no-down-event-binding }}
      {{on 'mousedown' this.dragStart}}
      {{on 'mouseup' this.dragEnd}}
      {{createRef 'Region'}}
    >
      <div class='name'>
        {{@region.name}}
      </div>

      {{#if @survey}}
        <div class='survey'>
          {{@region.surveyString}}
        </div>
      {{/if}}

      {{#if this.meetingIndex}}
        <div class='meeting-index'>
          {{this.meetingIndex}}
        </div>
      {{/if}}

      {{#if this.waypointMeetingIndex}}
        <div class='waypoint-meeting-index' data-test-waypoint-meeting-index>
          {{this.waypointMeetingIndex}}W
        </div>
      {{/if}}

      {{yield}}
    </div>
  </template>
}
