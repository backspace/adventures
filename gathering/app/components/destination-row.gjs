import { hash } from '@ember/helper';
import { on } from '@ember/modifier';
import { action } from '@ember/object';
import { LinkTo } from '@ember/routing';
import Component from '@glimmer/component';
import featureFlag from 'ember-feature-flags/helpers/feature-flag';

export default class DestinationRow extends Component {
  get hasMeetings() {
    return this.args.destination.meetings.length;
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
      class='destination even:bg-gray-50
        {{if @destination.isIncomplete 'border-l-4 border-x-red-500'}}
        {{if @destination.isComplete 'border-r-4 border-x-green-500'}}
        {{if this.hasMeetings 'meetings'}}'
    >
      {{#if (featureFlag 'destination-status')}}
        <td class='p-2 align-top'>
          <button
            class='status'
            type='button'
            {{on 'click' this.toggleStatus}}
          >{{this.status}}</button>
        </td>
      {{/if}}
      <td class='region p-2 align-top'>
        <LinkTo class='underline' @route='destinations.index' @query={{hash region-id=@destination.region.id}} data-test-destination-region>
          {{@destination.region.name}}
        </LinkTo>
      </td>
      <td class='description p-2 align-top'>{{@destination.description}}</td>
      <td class='answer p-2 align-top'>{{@destination.answer}}</td>
      <td class='mask hidden md:table-cell p-2 align-top'>{{@destination.mask}}</td>
      <td class='awesomeness p-2 align-top'>{{@destination.awesomeness}}</td>
      <td class='risk p-2 align-top'>{{@destination.risk}}</td>
      <td class='scheduled p-2 align-top'>{{if @destination.meetings '✓'}}</td>
      <td class='p-2 align-top'><LinkTo
          @route='destination'
          @model={{@destination}}
          class='edit underline'
        >Edit</LinkTo></td>
    </tr>
  </template>
}
