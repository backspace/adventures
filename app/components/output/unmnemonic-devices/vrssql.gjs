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
        this.args.meetings.map((meeting) => ({
          id: meeting.get('destination.region.id'),
          name: meeting.get('destination.region.name'),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get destinations() {
    return knex({ client: 'pg' })('unmnemonic_devices.destinations')
      .insert(
        this.args.meetings.map((meeting) => ({
          id: meeting.get('destination.id'),
          description: meeting.get('destination.description'),
          region_id: meeting.get('destination.region.id'),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get books() {
    return knex({ client: 'pg' })('unmnemonic_devices.books')
      .insert(
        this.args.meetings.map((meeting) => ({
          id: meeting.get('waypoint.id'),
          title: meeting.get('waypoint.name'),
          excerpt: this.devices.trimmedInnerExcerpt(
            meeting.get('waypoint.excerpt')
          ),
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
