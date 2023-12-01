import Component from '@glimmer/component';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { htmlSafe } from '@ember/template';

export default class SchedulerWaypointComponent extends Component {
  @action select() {
    this.args.select(this.args.waypoint);
  }

  get style() {
    return htmlSafe(
      `border-top-width: ${this.args.waypoint.get('meetings.length') * 2}px;`
    );
  }

  get isHighlighted() {
    return this.args.highlightedTeam?.waypoints
      .map((t) => t.id)
      .includes(this.args.waypoint.id);
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <li
      class='waypoint
        {{if @isSelected "selected"}}
        {{if this.isHighlighted "highlighted"}}'
      style={{this.style}}
      {{on 'click' this.select}}
      data-test-waypoint
      ...attributes
    >
      <div data-test-name>{{@waypoint.name}}</div>
    </li>
  </template>
}
