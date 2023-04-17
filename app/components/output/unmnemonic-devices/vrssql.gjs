import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import CopyButton from 'ember-cli-clipboard/components/copy-button';
import knex from 'knex';
import { concat } from '@ember/helper';

export default class TeamOverviewsComponent extends Component {
  @tracked src;

  @service('unmnemonic-devices') devices;

  get outputs() {
    let getterNames = ['books', 'regions', 'destinations', 'meetings'];

    return getterNames.map((getterName) => ({
      name: getterName,
      query: this[getterName].toString(),
    }));
  }

  get regions() {
    return knex({ client: 'pg' })('unmnemonic_devices.regions')
      .insert(
        this.args.regions.filterBy('isComplete').map((region) => ({
          id: region.get('id'),
          name: region.get('name'),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get destinations() {
    return knex({ client: 'pg' })('unmnemonic_devices.destinations')
      .insert(
        this.args.destinations.filterBy('isComplete').map((destination) => ({
          id: destination.get('id'),
          description: destination.get('description'),
          region_id: destination.get('region.id'),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get books() {
    return knex({ client: 'pg' })('unmnemonic_devices.books')
      .insert(
        this.args.waypoints.filterBy('isComplete').map((waypoint) => ({
          id: waypoint.get('id'),
          title: waypoint.get('name'),
          excerpt: this.devices.trimmedInnerExcerpt(waypoint.get('excerpt')),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get meetings() {
    return knex({ client: 'pg' })('unmnemonic_devices.meetings')
      .insert(
        this.args.meetings.map((meeting) => ({
          id: meeting.get('id'),
          team_id: meeting.get('teams.firstObject.id'),
          book_id: meeting.get('waypoint.id'),
          destination_id: meeting.get('destination.id'),
        }))
      )
      .onConflict(['id'])
      .merge();
  }

  <template>
    <table>
      <tbody>
        {{#each this.outputs as |output|}}
          <tr>
            <td>{{output.name}}</td>
            <td>
              <CopyButton
                class='button'
                @text={{output.query}}
              >Copy</CopyButton>

              <textarea
                rows='10'
                aria-label={{concat 'VRS SQL: ' output.name}}
                disabled
              >{{output.query}}</textarea>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
