import { fn, concat } from '@ember/helper';
import { on } from '@ember/modifier';
import Component from '@glimmer/component';
import createRef from 'ember-ref-bucket/modifiers/create-ref';
import { eq } from 'ember-truth-helpers';
import SchedulerDestination from 'gathering/components/scheduler/destination';
import SchedulerWaypoint from 'gathering/components/scheduler/waypoint';

export default class RegionContents extends Component {
  get region() {
    return this.args.container.region;
  }

  get isDestinations() {
    return this.args.type === 'destination';
  }

  get hasItems() {
    return this.isDestinations
      ? this.args.container.hasDestinations
      : this.args.container.hasWaypoints;
  }

  <template>
    {{#if this.hasItems}}
      <li
        class='region'
        data-test-scheduler-column-region
        id='{{if this.isDestinations '' 'waypoint-'}}region-{{this.region.id}}'
        title={{this.region.notes}}
        {{on 'mouseenter' (fn @mouseEnterRegion this.region)}}
        {{on 'mouseleave' @mouseLeaveRegion}}
        {{createRef (concat 'region-' this.region.id)}}
      >
        <div class='name' data-test-name>{{this.region.name}}</div>
        {{#if this.region.accessibility}}
          <div
            class='accessibility'
            data-test-region-accessibility
          >{{this.region.accessibility}}</div>
        {{/if}}

        {{#if this.isDestinations}}
          <ul class='destinations'>
            {{#each @container.destinations as |destination|}}
              {{#if destination.isAvailable}}
                <SchedulerDestination
                  data-test-scheduler-destination
                  @destination={{destination}}
                  @meeting={{@meeting}}
                  @select={{@select}}
                  @isSelected={{eq destination.id @meeting.destination.id}}
                  @highlightedTeam={{@highlightedTeam}}
                />
              {{/if}}
            {{/each}}
          </ul>
        {{else}}
          <ul class='waypoints'>
            {{#each @container.waypoints as |waypoint|}}
              <SchedulerWaypoint
                data-test-scheduler-waypoint
                @waypoint={{waypoint}}
                @select={{@select}}
                @isSelected={{eq waypoint.id @meeting.waypoint.id}}
                @highlightedTeam={{@highlightedTeam}}
              />
            {{/each}}
          </ul>
        {{/if}}

        {{#each @container.children as |childContainer|}}
          <RegionContents
            @container={{childContainer}}
            @type={{@type}}
            @mouseEnterRegion={{@mouseEnterRegion}}
            @mouseLeaveRegion={{@mouseLeaveRegion}}
            @select={{@select}}
            @meeting={{@meeting}}
            @highlightedTeam={{@highlightedTeam}}
          />

        {{/each}}
      </li>
    {{/if}}
  </template>
}
