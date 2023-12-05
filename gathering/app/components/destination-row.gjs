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
      class='destination
        {{if @destination.isIncomplete 'incomplete'}}
        {{if this.hasMeetings 'meetings'}}'
    >
      {{#if (featureFlag 'destination-status')}}
        <td>
          <button
            class='status'
            type='button'
            {{on 'click' this.toggleStatus}}
          >{{this.status}}</button>
        </td>
      {{/if}}
      <td class='region'>
        <LinkTo @route='destinations.index' @query={{hash region-id=@destination.region.id}} data-test-destination-region>
          {{@destination.region.name}}
        </LinkTo>
      </td>
      <td class='description'>{{@destination.description}}</td>
      <td class='answer'>{{@destination.answer}}</td>
      <td class='mask show-for-medium'>{{@destination.mask}}</td>
      <td class='awesomeness'>{{@destination.awesomeness}}</td>
      <td class='risk'>{{@destination.risk}}</td>
      <td class='scheduled'>{{if @destination.meetings '✓'}}</td>
      <td><LinkTo
          @route='destination'
          @model={{@destination}}
          class='edit'
        >Edit</LinkTo></td>
    </tr>
  </template>
}
