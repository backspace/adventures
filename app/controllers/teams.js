import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { all } from 'rsvp';
import Controller from '@ember/controller';
import { inject as service } from '@ember/service';

@classic
export default class TeamsController extends Controller {
  @service store;

  @action
  save() {
    const {data: teams} = JSON.parse(this.get('teamsJSON'));

    all(this.get('model').map(model => {
      return model.reload().then(reloaded => reloaded.destroyRecord());
    })).then(() => {
      const teamRecords = teams.map(({attributes}) => {
        const teamRecord = this.store.createRecord('team');
        teamRecord.setProperties(attributes);

        return teamRecord.save();
      });

      return all(teamRecords);
    });
  }
}
