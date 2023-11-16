import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import classic from 'ember-classic-decorator';
import { all } from 'rsvp';

@classic
export default class TeamsController extends Controller {
  @service puzzles;
  @service store;

  get sortedTeams() {
    return this.model.sortBy('name');
  }

  @action
  async save() {
    const { data: teams } = JSON.parse(this.teamsJSON);

    let saves = [];
    let updatedModels = [];

    teams.forEach((incomingTeam) => {
      let existingTeam = this.model.find(
        (existing) => existing.id === incomingTeam.id
      );

      if (existingTeam) {
        console.log(
          `updating team ${existingTeam.id}, name was ${existingTeam.name} and becomes ${incomingTeam.attributes.name}`
        );

        existingTeam.setProperties(incomingTeam.attributes);
        updatedModels.push(existingTeam);
        saves.push(existingTeam.save());
      } else {
        console.log('new incoming team', incomingTeam.attributes);

        let newTeam = this.store.createRecord('team', {
          id: incomingTeam.id,
          ...incomingTeam.attributes,
        });
        saves.push(newTeam.save());
      }
    });

    let unchangedTeams = this.model.filter(
      (existingTeam) => !updatedModels.includes(existingTeam)
    );

    if (unchangedTeams) {
      console.log(
        `found these unchanged teams, is it expected? ${unchangedTeams.mapBy(
          'name'
        )}`
      );
    }

    await all(saves);
  }
}
