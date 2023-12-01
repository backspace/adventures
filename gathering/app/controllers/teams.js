import Controller from '@ember/controller';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tracked } from '@glimmer/tracking';
import classic from 'ember-classic-decorator';
import sortBy from 'lodash.sortby';
import { all } from 'rsvp';

@classic
export default class TeamsController extends Controller {
  @service puzzles;
  @service store;

  @tracked modelsToSave;

  get sortedTeams() {
    let sorted = sortBy(this.model, (t) => t.name.toLowerCase());

    if (this.modelsToSave?.length) {
      return sorted.map((team) => ({
        current: team,
        changes: team.changedAttributes(),
      }));
    } else {
      return sorted.map((team) => ({ current: team }));
    }
  }

  @action
  async update() {
    const { data: teams } = JSON.parse(this.teamsJSON);

    let modelsToSave = [];

    teams.forEach((incomingTeam) => {
      let existingTeam = this.model.find(
        (existing) => existing.id === incomingTeam.id
      );

      if (existingTeam) {
        existingTeam.setProperties(incomingTeam.attributes);
        modelsToSave.push(existingTeam);
      } else {
        let newTeam = this.store.createRecord('team', {
          id: incomingTeam.id,
          ...incomingTeam.attributes,
        });

        modelsToSave.push(newTeam);
      }
    });

    this.modelsToSave = modelsToSave;
  }

  @action async save() {
    await all(this.modelsToSave.map((model) => model.save()));
    this.modelsToSave = [];
  }
}
