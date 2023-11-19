import Component from '@glimmer/component';
import { LinkTo } from '@ember/routing';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import featureFlag from 'ember-feature-flags/helpers/feature-flag';

export default class WaypointRowComponent extends Component {
  <template>
    <tr
      class='waypoint {{if @waypoint.isIncomplete "incomplete"}}'
      data-test-waypoint
    >
      {{! template-lint-disable no-invalid-interactive }}
      {{#if (featureFlag 'destination-status')}}<td
          class='status'
          {{on 'click' this.toggleStatus}}
          data-test-status
        >{{this.status}}</td>{{/if}}
      <td data-test-region>
        {{@waypoint.region.name}}
      </td>
      <td data-test-name>
        {{@waypoint.name}}
      </td>
      <td data-test-author>
        {{@waypoint.author}}
      </td>
      <td>
        <LinkTo @route='waypoint' @model={{@waypoint}} data-test-edit>
          Edit
        </LinkTo>
      </td>
    </tr>
  </template>

  get status() {
    const status = this.args.waypoint.status;

    if (status === 'available') {
      return '✓';
    } else if (status === 'unavailable') {
      return '✘';
    } else {
      return '?';
    }
  }

  @action
  toggleStatus() {
    const status = this.args.waypoint.status;
    let newStatus;

    if (status === 'available') {
      newStatus = 'unavailable';
    } else if (status === 'unavailable') {
      newStatus = undefined;
    } else {
      newStatus = 'available';
    }

    this.args.waypoint.status = newStatus;
    this.args.waypoint.save();
  }
}
