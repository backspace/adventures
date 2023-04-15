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
    let getterNames = ['books', 'teamBooks'];

    return getterNames.map((getterName) => ({
      name: getterName,
      query: this[getterName].toString(),
    }));
  }

  get books() {
    return knex({ client: 'pg' })('unmnemonic_devices.books')
      .insert(
        this.args.waypoints.filterBy('isComplete').map((book) => ({
          id: book.id,
          title: book.name,
          excerpt: this.devices.inExcerpt(book.excerpt),
        }))
      )
      .onConflict('id')
      .merge();
  }

  get teamBooks() {
    return knex({ client: 'pg' })('unmnemonic_devices.books_teams')
      .insert(
        this.args.meetings.map((meeting) => ({
          team_id: meeting.get('teams.firstObject.id'),
          book_id: meeting.get('waypoint.id'),
        }))
      )
      .onConflict(['team_id', 'book_id'])
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
