import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { htmlSafe } from '@ember/template';
import Component from '@glimmer/component';

export default class SchedulerDestinationComponent extends Component {
  get style() {
    return htmlSafe(
      `border-top-width: ${
        this.args.destination.get('meetings.length') * 2
      }px;` +
        `border-left-color: rgba(0, 0, 255, ${
          this.args.destination.get('awesomeness') / 10
        });` +
        `border-right-color: rgba(255, 0, 0, ${
          this.args.destination.get('risk') / 10
        });`
    );
  }

  get isHighlighted() {
    return this.args.highlightedTeam?.destinations
      .map((d) => d.id)
      .includes(this.args.destination.id);
  }

  @action select() {
    this.args.select(this.args.destination);
  }

  <template>
    {{! template-lint-disable no-inline-styles }}
    {{! template-lint-disable no-invalid-interactive }}
    <li
      class='destination
        {{if @isSelected "selected"}}
        {{if this.isHighlighted "highlighted"}}'
      title='A{{@destination.awesomeness}} R{{@destination.risk}}'
      style={{this.style}}
      {{on 'click' this.select}}
      ...attributes
    >
      <div class='description'>{{@destination.description}}</div>

      {{#if @destination.accessibility}}
        <div class='accessibility'>{{@destination.accessibility}}</div>
      {{/if}}
    </li>
  </template>
}
