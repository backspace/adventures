import { hash } from '@ember/helper';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { LinkTo } from '@ember/routing';
import Component from '@glimmer/component';
import featureFlag from 'ember-feature-flags/helpers/feature-flag';

export default class DestinationRow extends Component {
  get hasMeetings() {
    return this.args.destination.meetings.length > 0;
  }

  get status() {
    const status = this.args.destination.status;

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
    const status = this.args.destination.status;
    let newStatus;

    if (status === 'available') {
      newStatus = 'unavailable';
    } else if (status === 'unavailable') {
      newStatus = undefined;
    } else {
      newStatus = 'available';
    }

    this.args.destination.status = newStatus;
    this.args.destination.save();
  }

  <template>
    <tr
      class='even:bg-gray-50
        {{if @destination.isIncomplete 'border-l-4 border-x-red-500'}}
        {{if @destination.isComplete 'border-r-4 border-x-green-500'}}'
      data-test-destination
      data-test-has-meetings={{this.hasMeetings}}
    >
      {{#if (featureFlag 'destination-status')}}
        <td class='p-2 align-top'>
          <button
            type='button'
            {{on 'click' this.toggleStatus}}
            data-test-status
          >{{this.status}}</button>
        </td>
      {{/if}}
      <td class='p-2 align-top'>
        <LinkTo
          class='underline'
          @route='destinations.index'
          @query={{hash region-id=@destination.region.id}}
          data-test-destination-region
        >
          {{@destination.region.name}}
        </LinkTo>
      </td>
      <td
        class='p-2 align-top'
        data-test-description
      >{{@destination.description}}</td>
      <td class='p-2 align-top' data-test-answer>{{@destination.answer}}</td>
      <td
        class='hidden p-2 align-top md:table-cell'
        data-test-mask
      >{{@destination.mask}}</td>
      <td
        class='p-2 align-top'
        data-test-awesomeness
      >{{@destination.awesomeness}}</td>
      <td class='p-2 align-top' data-test-risk>{{@destination.risk}}</td>
      <td class='p-2 align-top' data-test-scheduled>{{if
          @destination.meetings
          '✓'
        }}</td>
      <td class='p-2 align-top'><LinkTo
          @route='destination'
          @model={{@destination}}
          class='underline'
          data-test-edit
        >Edit</LinkTo></td>
    </tr>
  </template>
}
