import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';

export default class SchedulerWaypointComponent extends Component {
  @action select() {
    this.args.select(this.args.waypoint);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <li
      class='waypoint {{if this.isSelected 'selected'}}'
      style={{this.style}}
      {{on 'click' this.select}}
      data-test-waypoint
    >
      <div class='description'>{{@waypoint.description}}</div>

      {{#if @waypoint.accessibility}}
        <div class='accessibility'>{{@waypoint.accessibility}}</div>
      {{/if}}
    </li>
  </template>
}
