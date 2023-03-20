import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';
import { all } from 'rsvp';

@classic
export default class TeamsController extends Controller {
  @service puzzles;
  @service store;

  @action
  save() {
    const { data: teams } = JSON.parse(this.teamsJSON);

    all(
      this.model.map((model) => {
        return model.reload().then((reloaded) => reloaded.destroyRecord());
      })
    ).then(() => {
      const teamRecords = teams.map(({ attributes }) => {
        const teamRecord = this.store.createRecord('team');
        teamRecord.setProperties(attributes);

        return teamRecord.save();
      });

      return all(teamRecords);
    });
  }
}
